package com.scoder.jusic.service;

/**
 * @author H
 */
public interface ConfigService {

    /**
     * set push switch
     *
     * @param pushSwitch boolean
     */
    void setPushSwitch(boolean pushSwitch,String houseId);

    void setEnableSwitch(boolean enableSwitch,String houseId);

    void setEnableSearch(boolean enableSearch,String houseId);
    void setVoteRate(Float voteRate,String houseId);

    Boolean getEnableSearch(String houseId);

    Boolean getEnableSwitch(String houseId);


    Boolean getGoodModel(String houseId);
    void setGoodModel(boolean goodModel,String houseId);

    Boolean getMusicCircleModel(String houseId);
    void setMusicCircleModel(boolean musicCircleModel,String houseId);

    Boolean getListCircleModel(String houseId);
    void setListCircleModel(boolean listCircleModel,String houseId);

    Boolean getRandomModel(String houseId);
    void setRandomModel(boolean goodModel,String houseId);

    Float getVoteRate(String houseId);

    /**
     * B 站直播弹幕点歌的房间配置：直播间号、是否自动连接、弹幕切歌门槛
     */
    String getBiliRoomId(String houseId);
    void setBiliRoomId(String roomId, String houseId);

    Boolean getBiliAutoConnect(String houseId);
    void setBiliAutoConnect(boolean autoConnect, String houseId);

    Integer getBiliSwitchLimit(String houseId);
    void setBiliSwitchLimit(Integer switchLimit, String houseId);

    void setQqMusicCookieToProperties();
    void setQqMusicCookie(String uin, String qqMusicCookie);
}
