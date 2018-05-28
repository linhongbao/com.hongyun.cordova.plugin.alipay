//
//  CDVAlipay.m
//  X5
//
//  Created by 007slm on 12/8/14.
//
//

#import "CDVAlipay.h"
#import "Order.h"
#import "DataSigner.h"
#import <AlipaySDK/AlipaySDK.h>

@implementation CDVAlipay


//当没有在appDeleate中存在(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString*, id> *)options 函数的时候被调用
//这个函数是用来处理回调的
-(void)handleOpenURL:(NSNotification *)notification{
    NSURL* url = [notification object];
    //跳转支付宝钱包进行支付，需要将支付宝钱包的支付结果回传给SDK
    if (url!=nil && [url.host isEqualToString:@"safepay"]) {
        [[AlipaySDK defaultService]processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            NSLog(@"result = %@", resultDic);

            
            NSString * resultStatus = [resultDic objectForKey:@"resultStatus"];
            CDVPluginResult* CDVresult = nil;
            if([resultStatus isEqual:@"9000"]){
                CDVresult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
            }else{
                CDVresult = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR  messageAsDictionary:resultDic];
            }
            
            [self.commandDelegate sendPluginResult:CDVresult callbackId:[self currentCallbackId]];
            
            [self endForExec];
            
         }];
    }
}


-(void)pluginInitialize{
}


-(void) prepareForExec:(CDVInvokedUrlCommand *)command{
    self.currentCallbackId = command.callbackId;
    
}

-(NSDictionary *)checkArgs:(CDVInvokedUrlCommand *) command{
    // check arguments
    NSDictionary *params = [command.arguments objectAtIndex:0];
    if (!params)
    {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"参数错误"] callbackId:command.callbackId];
        
        [self endForExec];
        return nil;
    }
    return params;
}

-(void) endForExec{
    self.currentCallbackId = nil;
}
- (NSString *)generateTradeNO
{
    static int kNumber = 15;
    
    NSString *sourceStr = @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    NSMutableString *resultStr = [[NSMutableString alloc] init];
    srand((unsigned)time(0));
    for (int i = 0; i < kNumber; i++)
    {
        unsigned index = rand() % [sourceStr length];
        NSString *oneStr = [sourceStr substringWithRange:NSMakeRange(index, 1)];
        [resultStr appendString:oneStr];
    }
    return resultStr;
}


- (void)pay:(CDVInvokedUrlCommand*)command{
    [self.commandDelegate runInBackground:^{
        [self payThread:command];
    }];
}
-(void)payThread:(CDVInvokedUrlCommand *)command{
    NSDictionary *params = [self checkArgs:command];
    [self prepareForExec:command];
    
    NSString *appScheme = @"alipaycordova";

    NSString * app_id = [params objectForKey:@"app_id"];
    NSString * sign_server = [params objectForKey:@"sign_server"];
    NSString * notify = [params objectForKey:@"notify"];
    NSString * timeout_express = [params objectForKey:@"timeout_express"];
    NSString * total_amount = [params objectForKey:@"total_amount"];
    NSString * subject = [params objectForKey:@"subject"];
    NSString * body = [params objectForKey:@"body"];
    NSString * out_trade_no = [params objectForKey:@"out_trade_no"];
    
    
    Order* order = [Order new];
    
    // NOTE: app_id设置
    order.app_id = app_id;
    
    // NOTE: 支付接口名称
    order.method = @"alipay.trade.app.pay";
    
    // NOTE: 参数编码格式
    order.charset = @"utf-8";
    
    // NOTE: 当前时间点
    NSDateFormatter* formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    order.timestamp = [formatter stringFromDate:[NSDate date]];
    
    // NOTE: 支付版本
    order.version = @"1.0";
    
    // NOTE: sign_type设置
    order.sign_type = @"RSA";
    
    
    // NOTE: 商品数据
    order.biz_content = [BizContent new];
    order.biz_content.body =  body;
    order.biz_content.subject = subject ;
    order.biz_content.out_trade_no = out_trade_no;
    order.biz_content.timeout_express = timeout_express;
    order.biz_content.total_amount = total_amount;
    order.notify_url = notify;
    
    NSString *orderInfo = [order orderInfoEncoded:NO];
    NSString *orderInfoEncoded = [order orderInfoEncoded:YES];
    
    NSLog(@"orderInfo = %@",orderInfo);
    NSLog(@"orderInfoEncoded = %@",orderInfoEncoded);
    //将商品信息拼接成字符串
    NSString *orderSpec = [order.biz_content description];
    NSLog(@"orderSpec = %@",orderSpec);
    
    NSDictionary *postdic = [NSMutableDictionary dictionary];
    
    
   
    
    [postdic setValue:app_id forKey:@"app_id"];
    [postdic setValue:orderSpec forKey:@"biz_content"];
    [postdic setValue:@"utf-8" forKey:@"charset"];
    [postdic setValue:@"alipay.trade.app.pay" forKey:@"method"];
    [postdic setValue:@"RSA" forKey:@"sign_type"];
    [postdic setValue:order.timestamp forKey:@"timestamp"];
    [postdic setValue:@"1.0" forKey:@"version"];
    [postdic setValue:notify forKey:@"notify_url"];
    
    NSString *signedString = [self getServerSign:sign_server postbd:postdic];
    
    NSLog(@"signedString = %@",signedString);
    //将签名成功字符串格式化为订单字符串,请严格按照该格式
    NSString *orderString = nil;

    orderString = [NSString stringWithFormat:@"%@&%@",orderInfoEncoded, signedString];
    
    //当用的是支付宝网页支付的时候，会跳转到这个
    //如果用的是支付宝app支付的时候，会走AppDeleagate
    [[AlipaySDK defaultService] payOrder:orderString fromScheme:appScheme callback:^(NSDictionary *resultDic) {
            NSLog(@"reslut = %@",resultDic);
        
            NSString * resultStatus = [resultDic objectForKey:@"resultStatus"];
            CDVPluginResult* CDVresult = nil;
            if([resultStatus isEqual:@"9000"]){
                CDVresult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
            }else{
                CDVresult = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR  messageAsDictionary:resultDic];
            }
            
            [self.commandDelegate sendPluginResult:CDVresult callbackId:[self currentCallbackId]];
            
            [self endForExec];
    }];

}

-(NSString*)getServerSign:(NSString*)URLstr postbd:(NSDictionary*)postbd{
    return [self postxml:URLstr postbd:postbd];
}
-(NSString *) postxml:(NSString*)URLstr postbd:(NSDictionary*)postbd
{
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:URLstr]];
    [request setHTTPMethod:@"POST"];//声明请求为POST请求
    //set headers
    NSString *contentType = [NSString stringWithFormat:@"text/xml"];//Content-Type数据类型设置xml类型
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    //create the body
    NSMutableData *postBody = [NSMutableData data];
    
    //这个提交的参数也是必须要按照ascii排序的
    NSMutableArray *numArray = [NSMutableArray arrayWithArray:postbd.allKeys];
    [numArray sortUsingComparator:^NSComparisonResult (NSString *str1, NSString *str2){
        return [str1 compare:str2];
    }];
    
    
    
    [postBody appendData:[[NSString stringWithFormat:@"<xml>"] dataUsingEncoding:NSUTF8StringEncoding]];
    for (NSString * key in numArray) {
        [postBody appendData:[[NSString stringWithFormat:@"<%@>%@</%@>",key,postbd[key],key] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [postBody appendData:[[NSString stringWithFormat:@"</xml>"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    [request setHTTPBody:postBody];
    
    NSString *bodyStr = [[NSString alloc] initWithData:postBody  encoding:NSUTF8StringEncoding];
    NSLog(@"bodyStr: %@ ",bodyStr);
    
    //get response
    NSHTTPURLResponse* urlResponse = nil;
    NSError *error = [[NSError alloc] init];
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
    NSString *result = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSLog(@"Response Code: %ld", (long)[urlResponse statusCode]);
    if ([urlResponse statusCode] >= 200 && [urlResponse statusCode] < 300) {
        NSLog(@"Response: %@", result);
        return result;
    }else{
        return @"";
    }
}
-(NSString*)getTimeStamp{
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"YYYY-MM-dd HH:mm:ss";
    NSDate *date = [[NSDate alloc] init];
    NSInteger numtime = date.timeIntervalSince1970;
    NSString *numtimestr = [NSString stringWithFormat:@"%ld",numtime];
    return numtimestr;
}
@end
