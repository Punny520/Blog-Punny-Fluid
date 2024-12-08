---
title: Mybatis-Plus字段自动填充(踩坑)
date: 2024-12-08 22:33:09
tags: [Mypatis-Plus,BUG]
categories: [学习笔记]
excerpt: Mybatis-Plus的字段自动填充用法和注意事项
index_img: /images/post/mybatis-plus.png
---
# Mybatis-Plus字段自动填充(踩坑)

> 在将项目从Mybatis换到Plus的时候，想给公共字段配置自动填充，但是中途出了点问题踩了一些坑

背景：给数据库表添加create_time、update_time两个公共字段，通过Mybatis-Plus实现自动填充

首先给数据库表中添加这两个字段

`create_time`类型为timestamp默认为null

`update_time`类型为timestamp默认为null

然后给对应实体类中添加对应属性字段：

```java
@TableField(fill = FieldFill.INSERT)
private LocalDateTime createTime;
@TableField(fill = FieldFill.INSERT_UPDATE)
private LocalDateTime updateTime;
```

使用@TableField注解，指定自动填充的类型，比如FieldFill.INSERT表示在插入的时候自动填充

FieldFill.INSERT_UPDATE在插入和删除的时候填充等

创建一个Handler实现MetaObjectHandler接口重写insertFill、updateFill方法在里面实现自己的填充逻辑

```java
@Component
@Slf4j
/**
 * 默认的自动填充策略：
 * 如果已经存在了值，则不填充
 * 如果填充的值为null也不填充
 */
public class FieldAutoFillHandler implements MetaObjectHandler {
    @Override
    public void insertFill(MetaObject metaObject) {
        log.info("执行插入填充...");
        this.strictInsertFill(metaObject, "createTime", LocalDateTime.class, LocalDateTime.now());
        this.strictUpdateFill(metaObject, "updateTime", LocalDateTime.class, LocalDateTime.now());
    }

    @Override
    public void updateFill(MetaObject metaObject) {
        log.info("执行更新填充...");
        this.setFieldValByName("updateTime", LocalDateTime.now(), metaObject);
    }

}
```

之后在更新或者删除的时候就可以实现自动填充

## 自动填充出现失效

正常一般这样配置后就可以用了，但是有些原因可能会导致失效，以及一些注意事项。

实体类属性的字段上是否加上了@TableField注解

数据库数据类型，和实体类数据类型是否对应

Handler是否加了@Component注解交给Spring管理

strictInsert/UpdateFill和setFieldValByName的区别：

这两个方法都是用来实现设置需要自动填充的字段的值

但是有些许差异首先strictInsert/UpdateFill的默认填充策略是：`如果实体类中需要自动填充的字段已经有值了(可能是在业务逻辑中就已经设置，或者是数据库中查出来的),那么当前值就不会进行填充，或者你想给一个字段填充null值也是不可以的。`

而setFieldValByName不一样，他就是直接覆盖

所以说有时候发现update_time不更新，有可能是在update的时候传入的实体类中已经有之前update_time，所以使用strictUpdateFill填充当前时间就会不生效，可以直接使用setFieldValByName

还有一种特殊情况，也是我自己遇到的，就是如果你的mapper接口继承了BaseMapper，里面会默认提供一些接口比如insert等，但是如果你还写了对应的insert的xml文件，那么在自动填充的时候可能会走你的xml文件中的sql逻辑，而不是框架自带的，这样的话自动填充可能会失效如果你的sql中没有去主动设置create_time、update_time这些值。





