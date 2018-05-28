package com.hongyun.cordova.plugin.alipay;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.Random;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaPreferences;
import org.json.JSONException;
import org.json.JSONObject;

import android.os.Handler;
import android.os.Message;
import android.view.View;
import android.widget.Toast;



import java.util.Map;

import com.alipay.sdk.app.AuthTask;
import com.alipay.sdk.app.PayTask;


import android.annotation.SuppressLint;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.widget.Toast;

import com.alipay.sdk.app.PayTask;

public class Alipay extends CordovaPlugin{
    private static final int SDK_PAY_FLAG = 1;
    CallbackContext currentCallbackContext;

    @Override
    public boolean execute(String action, CordovaArgs args,
                           CallbackContext callbackContext) throws JSONException {
        // save the current callback context
        currentCallbackContext = callbackContext;
        if (action.equals("pay")) {
             payV2(args);
        }
        return true;
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
    }

    @SuppressLint("HandlerLeak")
    private Handler mHandler = new Handler() {
        @SuppressWarnings("unused")
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case SDK_PAY_FLAG: {
                    @SuppressWarnings("unchecked")
                    PayResult payResult = new PayResult((Map<String, String>) msg.obj);
                    /**
                     对于支付结果，请商户依赖服务端的异步通知结果。同步通知结果，仅作为支付结束的通知。
                     */
                    String resultInfo = payResult.getResult();// 同步返回需要验证的信息
                    String resultStatus = payResult.getResultStatus();
                    String resultError = payResult.getMemo();
                    // 判断resultStatus 为9000则代表支付成功
                    if (TextUtils.equals(resultStatus, "9000")) {
                        currentCallbackContext.success();
                    } else {
                        JSONObject json = new JSONObject();
                        try {
                            json.put("resultStatus",resultStatus);
                            json.put("result",resultInfo);
                            json.put("memo",resultError);
                            currentCallbackContext.error(json);
                        } catch (JSONException e) {
                            e.printStackTrace();
                            currentCallbackContext.error(e.getMessage());
                        }

                    }
                    break;
                }
                default:
                    break;
            }
        };
    };

    /**
     * 支付宝支付业务
     *
     * @param
     */
    public void payV2(CordovaArgs args) {
         JSONObject orderInfoArgs = null;
          String timeout_express ="";
          String total_amount ="";
          String subject ="";
          String body ="";
          String out_trade_no ="";
          String app_id="";
          String sign_server="";
          String notify="";
        try {
            orderInfoArgs = args.getJSONObject(0);
            app_id        = orderInfoArgs.getString("app_id");
            sign_server   = orderInfoArgs.getString("sign_server");
            notify        = orderInfoArgs.getString("notify");
            timeout_express = orderInfoArgs.getString("timeout_express");
            total_amount = orderInfoArgs.getString("total_amount");
            subject = orderInfoArgs.getString("subject");
            body = orderInfoArgs.getString("body");
            out_trade_no = orderInfoArgs.getString("out_trade_no");

        } catch (JSONException e) {
            e.printStackTrace();
            currentCallbackContext.error(e.getMessage());
        }

        final String biz_content = OrderInfoUtil2_0.buildOrderBizContent(timeout_express,total_amount,subject,body,out_trade_no);
        final Map<String, String> params = OrderInfoUtil2_0.buildOrderParamMap(app_id,biz_content,notify);
        final String orderParam = OrderInfoUtil2_0.buildOrderParam(params);
        final String signServer = sign_server;

        Runnable payRunnable = new Runnable() {
            @Override
            public void run() {

                //改为移动到php端的签名
                String  sign       = OrderInfoUtil2_0.getServerSign(signServer,params);
                String  orderInfo  = orderParam + "&" + sign;

                PayTask alipay = new PayTask(cordova.getActivity());
                Map<String, String> result = alipay.payV2(orderInfo, true);

                Message msg = new Message();
                msg.what = SDK_PAY_FLAG;
                msg.obj = result;
                mHandler.sendMessage(msg);
            }
        };

        Thread payThread = new Thread(payRunnable);
        payThread.start();

    }
}
