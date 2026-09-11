package com.scoder.jusic;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * @author H
 */
@SpringBootApplication
@EnableScheduling
@EnableAsync
//@Controller
public class JusicApplication {

    public static void main(String[] args) {
        // 原实现写的是 SpringApplication.run(JusicApplication.class, "--debug")，
        // 把外部传入的 args 整个丢掉了，导致 java -jar xxx.jar --RedisHost=... --server.port=...
        // 这类命令行参数全部失效（只能靠 -D 系统属性或环境变量传参）。
        // 这里改为：把外部参数透传进去，同时保留原本默认打开 debug 日志的行为。
        List<String> merged = new ArrayList<>();
        merged.add("--debug");
        merged.addAll(Arrays.asList(args));
        SpringApplication.run(JusicApplication.class, merged.toArray(new String[0]));
    }

//    @GetMapping("/")
//    public String index(){
//        return "index.html";
//    }
}
