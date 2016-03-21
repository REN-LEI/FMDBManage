//
//  RENDatabaseUtil.h
//  FMDBDemo
//
//  Created by renlei on 15/10/17.
//  Copyright © 2015年 renlei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FMDB.h>


@interface RENDatabaseUtil : NSObject

/// 数据库地址
@property (copy, nonatomic, readonly) NSString *SQFilePath;

+ (RENDatabaseUtil *)shareInstance;


/**
 *  插入一条数据对象
 *
 *  @param obj Model
 *
 */
- (BOOL)insertDataWithObj:(NSObject *)obj;

/**
 *  开启事物插入一组数据（对象）
 *
 *  @note 如果失败会进行回滚
 *  @param objs 对象数组
 *
 */
- (BOOL)insertInDataTransactionWithObjs:(NSArray *)objs;

/**
 *  删除数据库表中全部数据
 *
 *  @param name 表名
 *
 */
- (BOOL)removeAllDataWIthTableName:(NSString *)name;

/**
 *  删除表数据数据，根据键值删除表中的对应的数据
 *
 *  @param name  表名
 *  @param key   字段
 *  @param value 值
 *
 */
- (BOOL)removeDataWithTableName:(NSString *)name forKey:(NSString *)key forValue:(id)value;


/**
 *  改
 *
 *  @param name 表名
 *  @param sql  语句
 *
 */
- (BOOL)updateDataWithTableName:(NSString *)name withSQLString:(NSString *)sql;

/**
 *  查询
 *
 *  @param name 表名
 *  @param sql  语句
 *
 *  @return 结果
 */
-(FMResultSet *)queryDataWithSQLString:(NSString *)sql;


/**
 *  查询表个数
 *
 *  @param tableName 表名
 *
 *  @return 个数
 */
- (NSInteger)queryNumberOfTableName:(NSString *)tableName;


@end
