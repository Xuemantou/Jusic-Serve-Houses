package com.scoder.jusic.service.imp;

import com.scoder.jusic.configuration.JusicProperties;
import com.scoder.jusic.service.MailService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URL;
import java.net.URLEncoder;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;

/**
 * @author H
 */
@Service
@Slf4j
public class MailServiceImpl implements MailService {

    @Autowired
    private JusicProperties jusicProperties;
    @Autowired
    private JavaMailSender javaMailSender;

    public static void main(String[] args) throws IOException, NoSuchAlgorithmException, KeyManagementException {
        boolean result = commonSendJ("https://sctapi.ftqq.com/xxx.send","你好啊","大杀四方");
    }
    public static boolean commonSendJ(String webUrl,String title,String desc) throws IOException, NoSuchAlgorithmException, KeyManagementException {
        String postData = "text=" + URLEncoder.encode(title, "UTF-8") + "&desp=" + URLEncoder.encode(desc, "UTF-8");

        HttpsURLConnection conn = null;

        URL url = new URL(webUrl);
        DataOutputStream wr;

        if (webUrl.contains("https:")){
            //是https
            //绕过证书
            SSLContext context = createIgnoreVerifySSL();
            conn = (HttpsURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");

            conn.setDoOutput(true);
            conn.setSSLSocketFactory(context.getSocketFactory());
            wr = new DataOutputStream(conn.getOutputStream());
        }else {
            conn = (HttpsURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");

            conn.setDoOutput(true);
            //当前链接是http
            wr = new DataOutputStream(conn.getOutputStream());
        }


        // 防止推送服务无响应时无限阻塞调用线程
        // （网易 cookie 失效告警是在取歌热路径上被调用的，不能卡住点歌）
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(8000);

        wr.writeBytes(postData);
        wr.flush();
        wr.close();

        int responseCode = conn.getResponseCode();
        BufferedReader in = new BufferedReader(new InputStreamReader(conn.getInputStream()));
        String inputLine;
        StringBuilder response = new StringBuilder();

        while ((inputLine = in.readLine()) != null) {
            response.append(inputLine);
        }
        in.close();
        return response.toString().indexOf("\"errno\":0") != -1;
    }
    //绕过SSL、TLS证书
    public static SSLContext createIgnoreVerifySSL() throws NoSuchAlgorithmException, KeyManagementException {
        SSLContext sc = SSLContext.getInstance("TLS");
        // 实现一个X509TrustManager接口，用于绕过验证，不用修改里面的方法
        X509TrustManager trustManager = new X509TrustManager() {
            @Override
            public void checkClientTrusted(
                    java.security.cert.X509Certificate[] paramArrayOfX509Certificate,
                    String paramString) throws CertificateException {
            }

            @Override
            public void checkServerTrusted(
                    java.security.cert.X509Certificate[] paramArrayOfX509Certificate,
                    String paramString) throws CertificateException {
            }

            @Override
            public java.security.cert.X509Certificate[] getAcceptedIssuers() {
                return null;
            }
        };

        sc.init(null, new TrustManager[]{trustManager}, null);
        return sc;
    }
    public boolean sendServerJ(String text,String desc){
        try{
            String url = jusicProperties.getServerJUrl();
            return commonSendJ(url,text,desc);
        }catch(Exception e){
            log.error("发送至Server酱失败：{}",e.getMessage());
        }
        return false;

    }
    @Override
    public boolean sendSimpleMail(String subject, String content) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(jusicProperties.getMailSendFrom());
        message.setTo(jusicProperties.getMailSendTo());
        message.setSubject(subject);
        message.setText(content);

        try {
            javaMailSender.send(message);
            return true;
        } catch (Exception e) {
            log.info("邮件发送异常: {}", e.getMessage());
            return false;
        }
    }

}
