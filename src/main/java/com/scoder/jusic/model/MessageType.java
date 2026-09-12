package com.scoder.jusic.model;

/**
 * @author H
 */

public enum MessageType {
    /**
     *
     */
    NOTICE("NOTICE"),
    ANNOUNCEMENT("ANNOUNCEMENT"),
    ONLINE("ONLINE"),
    SETTING_NAME("SETTING_NAME"),
    AUTH("AUTH"),
    AUTH_ROOT("AUTH_ROOT"),
    AUTH_ADMIN("AUTH_ADMIN"),
    MUSIC("MUSIC"),
    PICK("PICK"),
    CHAT("CHAT"),
    SEARCH("SEARCH"),
    SEARCH_SONGLIST("SEARCH_SONGLIST"),
    SEARCH_USER("SEARCH_USER"),
    PAUSE("PAUSE"),
    VOLUMN("VOLUMN"),
    GOODMODEL("GOODMODEL"),
    ADD_HOUSE("ADD_HOUSE"),
    ADD_HOUSE_START("ADD_HOUSE_START"),
    SEARCH_HOUSE("SEARCH_HOUSE"),
    ENTER_HOUSE_START("ENTER_HOUSE_START"),
    ENTER_HOUSE("ENTER_HOUSE"),
    HOUSE_USER("HOUSE_USER"),
    EDIT_HOUSE("EDIT_HOUSE"),
    HOUSE_INFO("HOUSE_INFO"),
    HOUSE_DESTROYED("HOUSE_DESTROYED"),
    DEFAULT_PLAYLIST("DEFAULT_PLAYLIST");

    MessageType(String type) {
        this.type = type;
    }

    private String type;

    public String type() {
        return this.type;
    }
}
