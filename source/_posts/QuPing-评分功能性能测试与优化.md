---
title: QuPing - 评分功能性能测试与优化
date: 2024-12-08 22:37:16
tags: [QuPing,测试,Jmeter,高并发,性能优化,BUG]
categories: [项目]
excerpt: 对QuPing项目的评分功能进行测试并优化
index_img: /images/post/quping.png
---
# QuPing - 评分功能性能测试与优化

通过Jmeter模拟1000个用户同时对一个评分项进行打分的情况。

数据生成代码:

```java
    @Test
    void doRatingData(){
        int userCount = 1000;
        Long ratingId = null;
        int totalRating = 0;
        //创建一个测试评分
        log.info("创建测试用评分...");
        Rating rating = new Rating();
        rating.setTitle("测试用评分");
        ratingMapper.insert(rating);
        log.info("创建完毕,评分id为:{}",rating.getId());
        ratingId = rating.getId();
        log.info("开始生成{}个用户token与随机请求体",userCount);
        try(FileOutputStream fos = new FileOutputStream("src/main/resources/doRatingData.csv")){
            fos.write("token,requestBody\n".getBytes());
            for(int i=1;i<=userCount;i++){
                User user = new User();
                user.setNickName(String.format("test-%s", RandomUtil.randomString(5)));
                user.setPassword("111111");
                user.setFirstLogin(false);
                userMapper.insert(user);
                String token = userService.getUserToken(user);
                int score = RandomUtil.randomInt(1, 6);//[1,6)
                HashMap<String, String> map = new HashMap<>();
                map.put("ratingId", ratingId.toString());
                map.put("score", String.valueOf(score));
                String requestBody = JSONUtil.toJsonStr(map);
                fos.write(String.format("%s %s\n",token,requestBody).getBytes());
                totalRating+=score;
            }
        }catch (Exception e){
            log.error(e.getMessage());
        }
        log.info("生成完毕,总评分{},评分人数{},期望结果(保留2位小数){}",
                totalRating
                ,userCount
                ,Math.round((double) totalRating / userCount * 100) / 100.0);
    }
```

将数据保存为csv文件，然后通过jmeter获取并发送请求

方式一：

为了防止在并发的情况下出现类似脏度或者覆盖等情况，我们可以考虑对整个过程进行加锁

保证每次只有一个线程在操作这些数据。

请求流程：

> 前端发送请求：/rating/doRating 请求方式为POST,请求参数为json包括ratingId和score，分别表示评分项的id和用户的打分，请求头需要带上Token 
>
> 后端解析token获取userId并且通过ratingId获取对应的Rating和UserRatingMapping,如果用户第一次评分则插入一行mapping记录否则修改并update

测试结果：

该测试均在数据库中数据很少的情况

![image-20241208215233075](https://cdn.yunjiujiu.xyz/blogimages/image-20241208215233075.png)

平均4s的延迟，非常卡，但是异常是0，然后数据库显示的结果也是正确的，没有并发问题，可以勉强使用。由于每次评分后都会修改评分项的信息，所以用缓存意义不大。

## 设计优化

对应每个评分项的最终得分的结果：最终得分 = 总的得分 / 评分人数

如果一个用户进行了打分，那么他的打分会被记录在UserRatingMapping中

也就是说，Rating中的最终评分(score)、评分人数(count)，只是作为展示和方便计算的作用

实际上的结果其实还是保存在UserRatingMapping中，即使Rating中的最终评分数据丢失了

我们还是能够通过查看UserRatingMapping中哪些用户对哪些评分项的打分来计算出对应的最终分数

所以就得出了一个结论，用户对评分项打分或者修改打分，本质上都是在修改UserRatingMapping，和Rating的关系不大

所以这个问题就变成了对于UserRatingMapping的高并发设计

首先是插入的情况，我们需要去避免重复的插入

然后是修改的情况，为了防止我们的修改被覆盖，我们可以使用乐观锁

然后Rating这个点，我们把他放在Redis中进行修改，利用Redis单线程的特性，来规避并发问题

最后评分的流程变成：

前端请求→乐观锁修改UserRatingMapping→修改成功后去Redis中修改Rating的信息(Lua)→利用消息队列去持久化，并且只消费最新的

## 途中遇到的BUG

一开始我打算先试试就正常从数据库中拿数据然后修改并更新，为了防止出错，我加上了事务注解@Transactional，还有为了防止并发的synchronized来修饰整个doRating方法

结果测了几次还是会有并发问题，就是评分项的评分count总是小于实际的请求数。

但是我明明加了synchronized啊？这就很奇怪了，后面陆续从请求是否全部到达、数据库执行是否有出错的，synchronized锁对象等这方面排查，但是都是正常的。后面无意把@Transactional注解去掉后，才得以解决。

后面想明白了就是@Transactional注解的问题，因为我的同步方法没有把事务囊括在其中，所以后续在高并发的情况会出现事务的并发问题。因为用了@Transactional注解，Spring是使用代理来执行我的同步方法，具体流程就是先开启事务，然后执行我的同步方法，提交事务。这就导致并发的情况下多个事务相互干扰，导致了不可重复读的问题，并且相互提交并覆盖数据。

所以说如果要使用同步方法操作事务，记得把事务也囊括在里面

可以使用编程式事务，或者在调用事务方法前加锁，但是不要在同类中调用，否则这样事务注解会失效。