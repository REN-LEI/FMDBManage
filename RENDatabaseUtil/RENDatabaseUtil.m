//
//  RENFDatabaseUtil.m
//  FMDBDemo
//
//  Created by renlei on 15/10/17.
//  Copyright © 2015年 renlei. All rights reserved.
//

#import "RENDatabaseUtil.h"
#import <objc/runtime.h>

@interface RENDatabaseUtil () {
    
    FMDatabaseQueue *_dataBaseQueue;
}


@end

@implementation RENDatabaseUtil

+ (NSString *)databasePath {
    
    return  [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",[[NSBundle mainBundle] bundleIdentifier]]];
}


+ (RENDatabaseUtil *)shareInstance {
    static RENDatabaseUtil *databaseUtil = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        databaseUtil = [[self alloc] initPrivate];
    });
    return databaseUtil;
}

- (instancetype)initPrivate {
    if (self = [super init]) {
        
        _SQFilePath = [[self class] databasePath];
        NSLog(@"____==%@",_SQFilePath);
        _dataBaseQueue = [FMDatabaseQueue databaseQueueWithPath:_SQFilePath];
    }
    return self;
}

/// 创建表sql语句  默认创建一个seqId主键
- (NSString *)createTableSqlWithObject:(NSObject *)obj {
    
    NSString *tabName = NSStringFromClass(obj.class);
    NSArray *property_name = [self fetchPropertyName:obj];
    NSString *creatSql = [NSString stringWithFormat:@"create table if not exists %@ (seqId integer primary key autoincrement,%@ )",tabName,[property_name componentsJoinedByString:@","]];
    return creatSql;
}

/// 判断数据库表是否存在，如果不存在则创建
- (BOOL)hasTableExists:(FMDatabase *)database withObject:(NSObject *)obj {
    
    BOOL res = [database tableExists:NSStringFromClass(obj.class)];
    if (!res) {
        NSString *string = [self createTableSqlWithObject:obj];
        res = [database executeUpdate:string];
        if (!res) {
            NSLog(@"数据库表创建错误");
        }
    }
    return res ;
}

/// 获取表所有字段名
- (NSArray *)getColumns:(NSObject *)obj
{
    NSMutableArray *columns = [NSMutableArray array];
    [_dataBaseQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(obj.class);
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
    }];
    return [columns copy];
}

///  存在这个表，比较是否相等，不相等，修改表
- (void)databaseColumnExists:(FMDatabase *)database withObject:(NSObject *)obj  {
    
    NSString *tableName = NSStringFromClass(obj.class);
    NSMutableArray *columns = [[NSMutableArray alloc] init];
    FMResultSet *resultSet = [database getTableSchema:tableName];
    while ([resultSet next]) {
        NSString *column = [resultSet stringForColumn:@"name"];
        [columns addObject:column];
    }
    
    NSPredicate *pre = [NSPredicate predicateWithFormat:@"NOT(SELF in %@)",columns];
    NSArray* addArray = [[self fetchPropertyName:obj] filteredArrayUsingPredicate:pre];
    
    if (addArray.count == 0) {
        return;
    }
    
    NSMutableString *sqlString = [[NSMutableString alloc] init];
    
    [addArray enumerateObjectsUsingBlock:^(NSString * _Nonnull existsName, NSUInteger idx, BOOL * _Nonnull stop)
     {
         if (![existsName isEqualToString:@"seqId"]) {
             if (![database columnExists:existsName inTableWithName:tableName]) {
                 NSString *sql = [NSString stringWithFormat:@"alter table %@ add column %@;",tableName,existsName];
                 [sqlString appendString:sql];
             }
         }
     }];
    
    [database executeStatements:sqlString];
}

/// 插入语句
- (NSString *)insertSqlString:(NSObject *)obj {
    
    NSString *tabName = NSStringFromClass(obj.class);
    NSArray *propertyName = [self fetchPropertyName:obj];
    NSMutableString *values = [[NSMutableString alloc] init];
    NSInteger a = propertyName.count;
    while (a) {
        a--;
        [values appendString:a?@"?,":@"?"];
    }
    NSString *insertSql = [NSString stringWithFormat:@"insert into %@(%@) values(%@)",tabName,[propertyName componentsJoinedByString:@","],values];
    return insertSql;
}

/// 更新数据操作
- (BOOL)executeUpdate:(FMDatabase *)db withObject:(NSObject *)obj {
    
    [self databaseColumnExists:db withObject:obj];
    
    NSString *insertSql = [self insertSqlString:obj];
    NSArray *propertyValue = [self fetchPropertyValue:obj];
    
    if (![db executeUpdate:insertSql withArgumentsInArray:propertyValue]) {
        NSLog(@"插入数据失败");
        [db close];
        return  NO;
    }
    return YES;
}



/// 插入一条数据
- (BOOL)insertDataWithObj:(NSObject *)obj {
    
    if (!obj) {
        return NO;
    }
    
    __block BOOL resutls = NO;
    
    [_dataBaseQueue inDatabase:^(FMDatabase *db) {
        
        if ([self hasTableExists:db withObject:obj]) {
            
            resutls = [self executeUpdate:db withObject:obj];
        }
    }];
    
    return resutls;
}

/// 插入一组数据
- (BOOL)insertInDataTransactionWithObjs:(NSArray *)objs {
    
    if (objs.count == 0) {
        return NO;
    }
    
    __block BOOL resutls = YES;
    
    [_dataBaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        if ([self hasTableExists:db withObject:objs[0]])
        {
            [objs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
             {
                 resutls = [self executeUpdate:db withObject:obj];
                 if (!resutls)
                 {
                     *stop = YES;
                     *rollback = YES;
                 }
             }];
        }
    }];
    
    return resutls;
}



/// 删除数据库中指定表
- (BOOL)removeAllDataWIthTableName:(NSString *)name {
    
    if (!name) {
        return NO;
    }
    NSString * sql = [NSString stringWithFormat:@"delete from %@",name];
    
    __block BOOL resutls ;
    [_dataBaseQueue inDatabase:^(FMDatabase *db) {
        if ([db tableExists:name]) {
            resutls = [db executeUpdate:sql];
        }
    }];
    return resutls;
}

/// 根据键值对删除表数据
- (BOOL)removeDataWithTableName:(NSString *)name forKey:(NSString *)key forValue:(id)value
{
    if (!name || !key || !value) {
        return NO;
    }
    __block BOOL resutls;
    
    [_dataBaseQueue inDatabase:^(FMDatabase *db) {
        
        if ([db tableExists:name]) {
            
            NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@ = ?",name,key];
            
            resutls = [db executeUpdate:sql,value];
        }
    }];
    
    return resutls;
}


- (BOOL)updateDataWithTableName:(NSString *)name withSQLString:(NSString *)sql {
    if (!name || !sql) {
        return NO;
    }
    __block BOOL resutls;
    [_dataBaseQueue inDatabase:^(FMDatabase *db) {
        if ([db tableExists:name]) {
            resutls = [db executeUpdate:sql];
        }
    }];
    return resutls;
}


/// 查询结果
- (FMResultSet *)queryDataWithSQLString:(NSString *)sql
{
    if (!sql) {
        return nil;
    }
    __block FMResultSet *res = nil;
    
    [_dataBaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        res = [db executeQuery:sql];
    }];
    
    return res;
}

/// 查询表行
- (NSInteger)queryNumberOfTableName:(NSString *)tableName
{
    NSString *sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", tableName];
    
    FMResultSet *res = [self queryDataWithSQLString:sql];
    NSInteger count = 0;
    while ([res next]) {
        count = [res intForColumnIndex:0];
    }
    return count;
}

/// 获取对象的属性名称
- (NSArray *)fetchPropertyName:(NSObject *)obj {
    
    unsigned int numIvars;
    objc_property_t *properties = class_copyPropertyList([obj class], &numIvars);
    NSMutableArray *array = [NSMutableArray array];
    for(int i = 0; i < numIvars; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
        [array addObject:propertyName];
    }
    free(properties);
    return array;
}


/// 获取对象的 属性值
- (NSArray *)fetchPropertyValue:(NSObject *)obj {
    
    unsigned int numIvars;
    objc_property_t *properties = class_copyPropertyList([obj class], &numIvars);
    NSMutableArray *array = [NSMutableArray array];
    
    for(int i = 0; i < numIvars; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
        id value = [self handlerForValue:[obj valueForKey:propertyName]];
        [array addObject:value];
    }
    free(properties);
    return array;
}

/// 在这里处理一些不可存储的 value
- (id)handlerForValue:(id)value {
    
    if (!value || [value isEqual:[NSNull null]]) {
        return [NSNull null];
    }
    NSArray *classType =  @[[NSString class],
                            [NSData class],
                            [NSNumber class],
                            [NSArray class],
                            [NSDictionary class]];
    
    __block id valueTemp = [NSNull null];
    [classType enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop)
     {
         if ([value isKindOfClass:obj])
         {
             if ([value isKindOfClass:[NSDictionary class]] ||
                 [value isKindOfClass:[NSArray class]])
             {
                 NSData *jsonData = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:NULL];
                 valueTemp = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
             } else {
                 valueTemp = value;
             }
             
             *stop = YES;
         }
     }];
    
    return valueTemp;
}



@end


