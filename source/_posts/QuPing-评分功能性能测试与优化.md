---
title: QuPing - 评分功能性能测试与优化
date: 2024-12-08 22:37:16
tags: [QuPing,测试,Jmeter,高并发,性能优化,BUG]
categories: [项目]
excerpt: 对QuPing项目的评分功能进行测试并优化
index_img: /images/post/quping.png
---
# QuPing - 评分功能性能测试与优化

通过Jmeter模拟1000个用户同时对一个评分项进行打分，来对比相同业务不同逻辑的性能优劣。

数据生成代码:

```java
@SneakyThrows
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
    Method getUserToken = userService.getClass().getDeclaredMethod("getUserToken", User.class);
    getUserToken.setAccessible(true);
    try(FileOutputStream fos = new FileOutputStream("src/main/resources/doRatingData.csv");
        FileOutputStream tokenFos = new FileOutputStream("src/main/resources/token.csv")){
        fos.write("token,requestBody\n".getBytes());
        for(int i=1;i<=userCount;i++){
            User user = new User();
            user.setNickName(String.format("test-%s", RandomUtil.randomString(5)));
            user.setPassword("111111");
            user.setFirstLogin(false);
            userMapper.insert(user);
            String token = (String) getUserToken.invoke(userService, user);
            tokenFos.write((token+"\n").getBytes());
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

通过${token}获取每一行的token，${requestBody}获取请求体

方式一无优化逻辑，朴素法：

为了防止在并发的情况下出现类似脏度或者覆盖等情况，我们可以考虑对整个过程进行加锁

保证每次只有一个线程在操作这些数据。

请求流程：

> 前端发送请求：/rating/doRating 请求方式为POST,请求参数为json包括ratingId和score，分别表示评分项的id和用户的打分，请求头需要带上Token 
>
> 后端解析token获取userId并且通过ratingId获取对应的Rating和UserRatingMapping,如果用户第一次评分则插入一行mapping记录否则修改并update

机器配置：

![image-20241210215252192](https://cdn.yunjiujiu.xyz/blogimages/image-20241210215252192.png)

开始测试：
数据库中只有1000条user数据和1条rating数据

jmeter配置1000个线程，1s的ramp-up qps为1000

模拟1000个用户在1s内同时对一个评分进行打分。

前1000次需要insert1000条后续都只要update

5000次结果如下：

![image-20241210220134559](https://cdn.yunjiujiu.xyz/blogimages/image-20241210220134559.png)

查看数据库，结果符合预期，表示没有出现并发问题。

平均第一次1000次insert的情况下平均为4s，后续加上4000次update总共平均是2.5s，最大值达到8s，虽然说没有异常，但是还是很慢的，而且最小值最大值相差太大了，不稳定。

## 设计优化

对应每个评分项的最终得分的结果：最终得分 = 总的得分 / 评分人数

如果一个用户进行了打分，那么他的打分会被记录在UserRatingMapping中

也就是说，Rating中的最终评分(score)、评分人数(count)，只是作为展示和方便计算的作用

实际上的结果其实还是保存在UserRatingMapping中，即使Rating中的最终评分数据丢失了

我们还是能够通过查看UserRatingMapping中哪些用户对哪些评分项的打分来计算出对应的最终分数

所以就得出了一个结论，用户对评分项打分或者修改打分，本质上都是在修改UserRatingMapping，和Rating的关系不大

所以这个问题就变成了对于UserRatingMapping的高并发设计

首先是插入的情况，我们需要去避免重复的插入，可以在user_rating_mapping表中给user_id和rating_id添加唯一索引，因为一般都是rating的数量大于user所以user_id在前面会好点

```mysql
ALTER TABLE user_rating_mapping
ADD UNIQUE INDEX unique_user_rating (user_id, rating_id);
```

然后是修改的情况，为了防止我们的修改被覆盖，我们可以使用乐观锁，因为评分只在意结果无所谓过程，所以直接用score作为乐观锁，如果失败了直接返回即可。

然后Rating这个点，我们把他放在Redis中进行修改，利用Redis单线程的特性，来规避并发问题(可以用lua脚本)，前端获取结果通过缓存获取，也能快速的得到结果。

对于数据的持久化，首先因为我们只关系最新的打分结果，不关心之前的过程，而且每次都是直接在redis上修改数据，所以redis上永远都是最新的数据，我们只需要定期将redis中的数据保存到数据库即可。

在简单的情况下我们可以通过spring的事件，在每次redis更新后都发送一个事件，通知去持久化redis中的数据，为了防止redis宕机导致数据丢失，可以将每次更新的rating实体作为参数传给监听器，叫监听器去将该数据持久化到数据库。

当然也可以用消息中间件代替，这个适合分布式的情况，并且消息中间件有更完善的消息处理机制。

最终我将打分逻辑改成：

通过乐观锁更新UserRatingMapping
如果更新成功，修改redis中的评分信息
更新失败，返回"你点的太快了"
在redis中检查评分的标志位，如果为1则直接返回
如果为0或者没有则设置为1,发布一个延迟一秒后发布的事件
监听器收到事件后，将标志位设置为0，并且从redis中获取评分数据保存到数据库中

标志位和延迟的组合可以防止每次请求都去更新数据库，当一个请求进来，发现标志位为1则表示接下该请求对redis的更改会在未来的时间内<=1s被更新到数据库，所以该请求就不必要去访问数据库了。这样进行了一个限流的操作，就是假设2s内有5000个请求来，可能就只会访问两次数据库，大大节省了资源。

开始测试：

同样的机器和测试参数：

第一次1000平均1513ms，最小1190ms，最大1861对比4s平均大概提升了60%多

![image-20241210222940029](https://cdn.yunjiujiu.xyz/blogimages/image-20241210222940029.png)

最终5000次的结果发现平均才464ms，整体提升了80%!!!

并且也是0异常数据库结果符合预期。

后续又跑了1w次并且不断修改请全体改变评分，平均在350ms左右。

测试还是不太全面，但是总的还是有些提升。

## 途中遇到的BUG

一开始我打算先试试就正常从数据库中拿数据然后修改并更新，为了防止出错，我加上了事务注解@Transactional，还有为了防止并发的synchronized来修饰整个doRating方法

结果测了几次还是会有并发问题，就是评分项的评分count总是小于实际的请求数。

但是我明明加了synchronized啊？这就很奇怪了，后面陆续从请求是否全部到达、数据库执行是否有出错的，synchronized锁对象等这方面排查，但是都是正常的。后面无意把@Transactional注解去掉后，才得以解决。

后面想明白了就是@Transactional注解的问题，因为我的同步方法没有把事务囊括在其中，所以后续在高并发的情况会出现事务的并发问题。因为用了@Transactional注解，Spring是使用代理来执行我的同步方法，具体流程就是先开启事务，然后执行我的同步方法，提交事务。这就导致并发的情况下多个事务相互干扰，导致了不可重复读的问题，并且相互提交并覆盖数据。

所以说如果要使用同步方法操作事务，记得把事务也囊括在里面

可以使用编程式事务，或者在调用事务方法前加锁，但是不要在同类中调用，否则这样事务注解会失效。