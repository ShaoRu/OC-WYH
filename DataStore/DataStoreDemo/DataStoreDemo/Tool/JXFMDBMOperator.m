//
//  JXFMDBMOperator.m
//  DataStoreDemo
//
//  Created by hnbwyh on 2018/7/20.
//  Copyright © 2018年 hainbwyh. All rights reserved.
//

#import "JXFMDBMOperator.h"
#import <objc/runtime.h>


@interface JXDataModelParser ()



@end

@implementation JXDataModelParser

/**
 ---------------------------------------------------------- runtime 解析出 type
 key :_name
 type:@"NSString"
 
 key :_boolTest
 type:B
 
 NSInteger
 key :_age
 type:q
 
 NSUInteger
 key :_ageTest
 type:Q
 
 key :_intTest
 type:i
 
 float
 key :_floatTest
 type:f
 
 double
 key :_mark
 type:d
 
 key :_markTest
 type:d
 
 key :_subs
 type:@"NSArray"
 
 key :_classRoom
 type:@"NSDictionary"
 
 key :_son
 type:@"Son"
 
 key :_name
 type:@"NSString"
 
 ---------------------------------------------------------- OC 类型 与 sqlite 中类型间的映射
 
 NSString
 - text
 
 NSInteger
 - integer
 
 CGFloat
 - real
 
 NSArray/NSDictionary
 -
 
 **/


#pragma mark -

-(NSString *)sqlForTableKeyWithModelCls:(Class)modelCls{
    NSMutableString *rltSql = [NSMutableString new];
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(modelCls, &count);
    for (NSInteger index = 0; index < count; index ++) {
        Ivar ivar = ivars[index];
        const char *keyName = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        NSString *typeString = [NSString stringWithCString:type encoding:NSUTF8StringEncoding];
        NSString *keyNameString = [NSString stringWithCString:keyName encoding:NSUTF8StringEncoding];
        NSString *sqlKey = [keyNameString substringFromIndex:1];
        [rltSql appendString:[NSString stringWithFormat:@" %@ %@",sqlKey,[self sqlMapWithType:typeString]]];
        NSLog(@"\n \n key :%@ \n type:%@ \n sqlKey :%@ \n \n",keyNameString,typeString,sqlKey);
        if (index != count - 1) {
            [rltSql appendString:@","];
        }
    }
    return rltSql;
}

#pragma mark -
- (NSString *)sqlMapWithType:(NSString *)type{
    NSString *rlt = @"blob";
    if ([type rangeOfString:@"NSString"].location != NSNotFound) {
        rlt = @"text";
    }else if ([type isEqualToString:@"B"] || [type isEqualToString:@"i"]
              || [type isEqualToString:@"q"] || [type isEqualToString:@"Q"]) {
        rlt = @"integer";
    }else if ([type isEqualToString:@"f"] || [type isEqualToString:@"d"]) {
        rlt = @"real";
    }
    return rlt;
}

#pragma mark -

-(NSString *)sqlForInsertDataIntoTableWithModel:(id)model{
    NSString *rlt;
    NSMutableString *keySql     = [NSMutableString stringWithString:@"("];
    NSMutableString *valueSql   = [NSMutableString stringWithString:@"values ("];
    
    // runtime 解析 key - value
    unsigned int count = 0;
    // 1. runtime 技术获取实例变量列表
    Ivar *ivars = class_copyIvarList([model class], &count);
    for (NSInteger index = 0; index < count; index ++) {
        Ivar ivar = ivars[index];
        // 2. 遍历获取变量 “名字” ，并转换成 OC 对象 --- 相应的类型同样可取
        const char *keyName = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        NSString *keyNameString = [NSString stringWithCString:keyName encoding:NSUTF8StringEncoding];
        NSString *typeString = [NSString stringWithCString:type encoding:NSUTF8StringEncoding];
        NSString *typeForSql = [self sqlMapWithType:typeString];
        
        // 3. KVC 技术获取 value
        id value = [model valueForKeyPath:keyNameString];
        if ([typeForSql isEqualToString:@"blob"] || [typeForSql isEqualToString:@"BLOB"]) {
            value = [NSKeyedArchiver archivedDataWithRootObject:value];
        }
        [self.modelValues addObject:value];
        
        // 4. 拼接 sql 语句
        [keySql appendFormat:@"%@",[keyNameString substringFromIndex:1]];
        (index != count - 1) ? [keySql appendFormat:@", "] : [keySql appendFormat:@") "];
        
        [valueSql appendFormat:@"?"];
        (index != count - 1) ? [valueSql appendFormat:@", "] : [valueSql appendFormat:@");"];
    }
    // 5. 对 C 语言(不具备ARC功能)部分涉及 Copy 操作的部分注意内存释放问题
    free(ivars);
    rlt = [NSString stringWithFormat:@"%@ %@",keySql,valueSql];
    return rlt;
}


#pragma mark - 数据查询结果配置数据

-(void)configValuesForModel:(id)model rltSet:(FMResultSet *)rltSet{
    // runtime 解析 key - value
    unsigned int count = 0;
    // 1. runtime 技术获取实例变量列表
    Ivar *ivars = class_copyIvarList([model class], &count);
    for (NSInteger index = 0; index < count; index ++) {
        Ivar ivar = ivars[index];
        // 2. 遍历获取变量 “名字” ，并转换成 OC 对象 --- 相应的类型同样可取
        const char *keyName = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        NSString *keyNameString = [NSString stringWithCString:keyName encoding:NSUTF8StringEncoding];
        NSString *dataType = [NSString stringWithCString:type encoding:NSUTF8StringEncoding];
        [self configModel:model dataType:dataType key:[keyNameString substringFromIndex:1] rltSet:rltSet];
    }
    // 3. 对 C 语言(不具备ARC功能)部分涉及 Copy 操作的部分注意内存释放问题
    free(ivars);
}

- (void)configModel:(id)model dataType:(NSString *)dataType key:(NSString *)key rltSet:(FMResultSet *)rltSet{
    if ([dataType rangeOfString:@"NSString"].location != NSNotFound) {
        [model setValue:[rltSet stringForColumn:key] forKey:key];
    }else if ([dataType isEqualToString:@"B"]) {
        [model setValue:[NSNumber numberWithBool:[rltSet boolForColumn:key]] forKey:key];
    }else if ([dataType isEqualToString:@"i"]) {
        [model setValue:[NSNumber numberWithInt:[rltSet intForColumn:key]] forKey:key];
    }else if ([dataType isEqualToString:@"q"]) {
        [model setValue:[NSNumber numberWithInteger:[rltSet longForColumn:key]] forKey:key];
    }else if ([dataType isEqualToString:@"Q"]) {
        [model setValue:[NSNumber numberWithUnsignedInteger:[rltSet unsignedLongLongIntForColumn:key]] forKey:key];
    }else if ([dataType isEqualToString:@"f"] || [dataType isEqualToString:@"d"]) {
        [model setValue:[NSNumber numberWithFloat:[rltSet doubleForColumn:key]] forKey:key];
    }else{
        id obj = [NSKeyedUnarchiver unarchiveObjectWithData:[rltSet objectForColumnName:key]];
        [model setValue:obj forKey:key];
    }
}

#pragma mark - lazy load

-(NSMutableArray *)modelValues{
    if(!_modelValues){
        _modelValues = [NSMutableArray new];
    }
    return _modelValues;
}

@end


@interface JXFMDBMOperator ()
{
    BOOL isLog;
}
@property (nonatomic,copy)   NSString                       *dbName;
@property (nonatomic,strong) FMDatabaseQueue                *dataBaseQueue;
@property (nonatomic,strong) JXDataModelParser              *modelParser;

@end

@implementation JXFMDBMOperator

+(instancetype)sharedInstance{
    static JXFMDBMOperator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[JXFMDBMOperator alloc] init];
        // 初始化必要参数
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        instance.dbName = info[@"CFBundleExecutable"];
    });
    return instance;
}

- (void)openLog{
    isLog = TRUE;
}

#pragma mark - 删除数据库

- (BOOL)deleteDataBaseWithdbName:(NSString *)dbName{
    BOOL rlt = TRUE;
    NSString *filePath = [self filePathWithFileName:dbName];
    rlt = [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    rlt ? [self printLogMsg:[NSString stringWithFormat:@"数据库删除成功，地址：%@",filePath]] : [self printLogMsg:[NSString stringWithFormat:@"数据库删除失败，地址：%@",filePath]];
    return rlt;
}

#pragma mark - 新建数据库

- (BOOL)createDataBaseWithdbName:(NSString *)dbName{
    self.dbName = dbName ? dbName : self.dbName;
    BOOL rlt = TRUE;
    NSString *filePath = [self filePathWithFileName:self.dbName];
    FMDatabase *dataBase = [[FMDatabase alloc] initWithPath:filePath];
    rlt = [self openDataBase:dataBase];
    rlt ? [self printLogMsg:[NSString stringWithFormat:@"数据库新建成功并打开，地址：%@",filePath]] : [self printLogMsg:[NSString stringWithFormat:@"数据库新建失败，地址：%@",filePath]];
    return rlt;
}

#pragma mark - 建表
-(BOOL)createTableWithModelCls:(Class)modelCls{
    __block BOOL rlt = FALSE;
    NSString *sql = [NSString stringWithFormat:@"create table if not exists %@ (customId integer primary key autoincrement,%@);",NSStringFromClass(modelCls),[self.modelParser sqlForTableKeyWithModelCls:modelCls]];
    [self.dataBaseQueue inDatabase:^(FMDatabase *db) {
        NSString *msg = [NSString stringWithFormat:@"数据库,数据表%@创建失败",NSStringFromClass(modelCls)];
        if ([self openDataBase:db]) {
            rlt = [db executeUpdate:sql];
            msg = [NSString stringWithFormat:@"数据库,数据表%@创建成功",NSStringFromClass(modelCls)];
        }
        [self printLogMsg:msg];
    }];
    return rlt;
}

#pragma mark - 插入数据

-(BOOL)insertDataModel:(id)model{
    __block BOOL rlt = FALSE;
    // 1. 先判断数据表是否存在
    if (![self isExistTable:NSStringFromClass([model class])]) {
        [self createTableWithModelCls:[model class]];
    }
    // 2. 插入数据
    [self.dataBaseQueue inDatabase:^(FMDatabase *db) {
        if ([self openDataBase:db]) {
            NSString *sql = [NSString stringWithFormat:@"insert into %@ %@",NSStringFromClass([model class]),[self.modelParser sqlForInsertDataIntoTableWithModel:model]];
            NSLog(@"\n %@ \n",sql);
            if ([db executeUpdate:sql withArgumentsInArray:self.modelParser.modelValues]) {
                rlt = TRUE;
            }
            [self.modelParser.modelValues removeAllObjects];
        }
    }];
    rlt ? [self printLogMsg:@"数据插入成功"] : [self printLogMsg:@"数据插入失败"];
    return rlt;
}

#pragma mark - 读取数据库数据

-(NSArray *)queryDataForModelCls:(Class)modelCls querySql:(NSString *)querySql orderKey:(NSString *)orderKey{
   __block NSMutableArray *rlt = [NSMutableArray new];
    if ([self isExistTable:NSStringFromClass(modelCls)]) {
        [self.dataBaseQueue inDatabase:^(FMDatabase *db) {
            if ([self openDataBase:db]) {
                NSString *tmpQuerySql = querySql ? [NSString stringWithFormat:@"where %@",querySql] : @"";
                NSString *sql = [NSString stringWithFormat:@"select * from %@ %@ order by %@ asc",NSStringFromClass(modelCls),tmpQuerySql,orderKey];
                FMResultSet *rltSet = [db executeQuery:sql];
                while ([rltSet next]) {
                    id model = [modelCls new];
                    [self.modelParser configValuesForModel:model rltSet:rltSet];
                    [rlt addObject:model];
                }
            }
        }];
    }
    return rlt;
}

#pragma mark ------ private method

#pragma mark - 存储路径

- (NSString *)filePathWithFileName:(NSString *)fileName{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",fileName]];
    [self printLogMsg:[NSString stringWithFormat:@"数据库存储路径：%@",filePath]];
    return filePath;
}

#pragma mark - 打开数据库

- (BOOL)openDataBase:(FMDatabase *)db{
    return [db open];
}

#pragma mark - 关闭数据库

- (BOOL)closeDataBase:(FMDatabase *)db{
    return [db open] ? [db close] : TRUE;
}

#pragma mark - 判断数据表是否存在

- (BOOL)isExistTable:(NSString *)tableName{
    __block BOOL rlt = FALSE;
    NSString *sql = [NSString stringWithFormat:@"select count(name) as countNum from sqlite_master where type = 'table' and name = '%@'", tableName];
    [self.dataBaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *rltSet = [db executeQuery:sql];
        while ([rltSet next]) {
            NSInteger count = [rltSet intForColumn:@"countNum"];
            if (count == 1) {
                rlt = TRUE;
            }
        }
        [rltSet close];
    }];
    return rlt;
}

#pragma mark - log
- (void)printLogMsg:(NSString *)msg{
    isLog ? NSLog(@"\n %@ \n",msg) : nil;
}

#pragma mark - lazy load
-(JXDataModelParser *)modelParser{
    if(!_modelParser){
        _modelParser = [[JXDataModelParser alloc] init];
    }
    return _modelParser;
}

-(FMDatabaseQueue *)dataBaseQueue{
    if (!_dataBaseQueue) {
        _dataBaseQueue = [FMDatabaseQueue databaseQueueWithPath:[self filePathWithFileName:self.dbName]];
    }
    return _dataBaseQueue;
}

#pragma mark - test
- (void)testMethod:(id)modelCls{
    
}

@end
