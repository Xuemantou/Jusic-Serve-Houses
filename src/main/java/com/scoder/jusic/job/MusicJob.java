package com.scoder.jusic.job;

import com.scoder.jusic.common.message.Response;
import com.scoder.jusic.configuration.HouseContainer;
import com.scoder.jusic.configuration.JusicProperties;
import com.scoder.jusic.model.House;
import com.scoder.jusic.model.MessageType;
import com.scoder.jusic.model.Music;
import com.scoder.jusic.repository.ConfigRepository;
import com.scoder.jusic.repository.MusicPlayingRepository;
import com.scoder.jusic.repository.MusicVoteRepository;
import com.scoder.jusic.repository.SessionRepository;
import com.scoder.jusic.service.MusicService;
import com.scoder.jusic.service.SessionService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import javax.annotation.PreDestroy;
import java.util.LinkedList;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;


/**
 * @author H
 */
@Component
@Slf4j
public class MusicJob {

    private final ExecutorService executorService;
    private final ConcurrentHashMap<String, AtomicBoolean> houseTaskMap;
    private final JusicProperties jusicProperties;

    public MusicJob(JusicProperties jusicProperties) {
        int cpuCores = Runtime.getRuntime().availableProcessors();
        this.executorService = new ThreadPoolExecutor(
                cpuCores+1, // 核心线程数
                cpuCores*2, // 最大线程数
                60L, TimeUnit.SECONDS, // 空闲线程存活时间
                new LinkedBlockingQueue<>(jusicProperties.getHouseSize()/3), // 阻塞队列大小
                new ThreadPoolExecutor.CallerRunsPolicy() // 拒绝策略
        );
        this.jusicProperties = jusicProperties;
        this.houseTaskMap = new ConcurrentHashMap<>();

    }

    @Autowired
    private MusicPlayingRepository musicPlayingRepository;
    @Autowired
    private ConfigRepository configRepository;
    @Autowired
    private MusicVoteRepository musicVoteRepository;
    @Autowired
    private SessionRepository sessionRepository;
    @Autowired
    private SessionService sessionService;
    @Autowired
    private MusicService musicService;
    @Autowired
    private HouseContainer houseContainer;

    /**
     * 广播条件：第一次启动时 playing 为空、音乐播放完毕、投票切歌
     */
    @Scheduled(fixedRate = 500)
    private void sendIfSufficient() {
        CopyOnWriteArrayList<House> houses = houseContainer.getHouses();
        for(House house : houses){
            if(!jusicProperties.getSessions(house.getId()).isEmpty()){//没人就不推送
//                log.info("houseName:{},houseId:{}",house.getName(),house.getId());
                try{
                    if (this.isPlayingNull(house.getId())) {
                        configRepository.setPushSwitch(true,house.getId());
                        log.info("推送开关开启, 原因: 首次启动"+house.getName());
                    } else if (this.isPlayingOver(house.getId())) {
                        configRepository.setPushSwitch(true,house.getId());
                        log.info("推送开关开启, 原因: 上一首播放完毕");
                    } else if (this.isPlayingSkip(house.getId())) {
                        configRepository.setPushSwitch(true,house.getId());
                        log.info("推送开关开启, 原因: 投票通过");
                    }

                    if (this.isPushSwitchOpen(house.getId())) {
                        houseTaskMap.computeIfAbsent(house.getId(), id -> new AtomicBoolean(false));

                        if (houseTaskMap.get(house.getId()).compareAndSet(false, true)) {
                            executorService.submit(() -> {
                                try {
                                    processHouse(house);
                                } catch (Exception e) {
                                    handleException(e, house);
                                } finally {
                                    houseTaskMap.remove(house.getId());
                                }
                            });
                        }
                    }
                }catch(Exception e){
                  handleException(e,house);
                }
            }else if(!JusicProperties.HOUSE_DEFAULT_ID.equals(house.getId()) && house != null && (house.getEnableStatus() == null || !house.getEnableStatus()) && (System.currentTimeMillis()-house.getCreateTime() > 20000)){
                    houseContainer.destroy(house.getId());
            }
//

        }

    }
    private void handleException(Exception e, House house) {
        try {
            configRepository.destroy(house.getId());
            musicPlayingRepository.destroy(house.getId());
        } catch (Exception e2) {
            log.error("定时任务销毁config及playing异常[{}]", e2.getMessage());
        }
        log.error("houseName:{},houseId:{},message:[{}]", house.getName(), house.getId(), e.getMessage());
    }
    @PreDestroy
    public void shutdown() {
        executorService.shutdown();
    }
    private void processHouse(House house){
        log.info("检测到推送开关已开启");
        Music music = musicService.musicSwitch(house.getId());
        // musicSwitch 在「默认列表里的歌全都取不到播放地址」时会返回 null
        // （原实现兜底到李志歌单，该功能已移除）。必须在这里提前返回：
        // 往下走马上就会访问 music.getDuration()。
        // 同时记得关掉推送开关，否则定时任务会一直重试同一轮。
        if (music == null) {
            log.info("本轮没有可推送的歌曲，跳过：{}", house.getName());
            configRepository.setPushSwitch(false, house.getId());
            return;
        }
        long pushTime = System.currentTimeMillis();
        if(music.getDuration() == null){
            music.setDuration(300000L);
        }
        configRepository.setLastMusicPushTimeAndDuration(pushTime, music.getDuration(),house.getId());
        music.setPushTime(pushTime);
        sessionService.send(MessageType.MUSIC, Response.success(music, "正在播放"),house.getId());
        musicPlayingRepository.leftPush(music,house.getId());//更新music pushTime
        musicPlayingRepository.keepTheOne(house.getId());
        log.info("已保存推送时间和音乐时长"+house.getName());
        configRepository.setPushSwitch(false,house.getId());
        log.info("已关闭音乐推送开关"+house.getName());
        musicVoteRepository.reset(house.getId());
        log.info("已重置投票");
//                        log.info("已向所有客户端推送音乐, 音乐: {}, 时长: {}, 推送时间: {}, 链接: {}", music.getName(), music.getDuration(), pushTime, music.getUrl());
        LinkedList<Music> result = musicService.getPickList(house.getId());
        sessionService.send(MessageType.PICK, Response.success(result, "播放列表"),house.getId());
//                        log.info("已向客户端推送播放列表, 共 {} 首, 列表: {}", result.size(), result);

    }

    private boolean isPushSwitchOpen(String houseId) {
        Boolean pushSwitch = configRepository.getPushSwitch(houseId);
        return pushSwitch == null ? false : pushSwitch;
    }

    private boolean isGoodModel(String houseId){
        Boolean goodModel = configRepository.getGoodModel(houseId);
        return goodModel == null ? false:goodModel;
    }

    private boolean isPlayingSkip(String houseId) {
        Long voteSize = musicVoteRepository.size(houseId);
        Integer sessionSize = jusicProperties.getSessions(houseId).size();
        Float voteRate = configRepository.getVoteRate(houseId);
        if (voteSize != null && voteSize != 0 && sessionSize != null && voteRate != null) {
            return voteSize >= sessionSize * voteRate;
        }
        return false;
    }

    private boolean isPlayingOver(String houseId) {
        Long lastMusicDuration = configRepository.getLastMusicDuration(houseId);
        Long lastMusicPushTime = configRepository.getLastMusicPushTime(houseId);
        if(null == lastMusicDuration || null == lastMusicPushTime){
            return true;
        }
//        if (null != lastMusicDuration && null != lastMusicPushTime) {
//            return (lastMusicPushTime + lastMusicDuration) - System.currentTimeMillis() <= 0;
//        }

//        return false;
        return (lastMusicPushTime + lastMusicDuration) - System.currentTimeMillis() <= 0;
    }

    private boolean isPlayingNull(String houseId) {
        return null == musicPlayingRepository.getPlaying(houseId);
    }

    public static void main(String[] args){
        int cpuCores = Runtime.getRuntime().availableProcessors();

        // 根据 CPU 核心数设置核心线程数和最大线程数
        int corePoolSize = cpuCores + 1;
        int maximumPoolSize = cpuCores * 2;

        System.out.println(cpuCores);
    }
}
