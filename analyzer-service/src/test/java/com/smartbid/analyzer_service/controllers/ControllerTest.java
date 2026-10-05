package com.smartbid.analyzer_service.controllers;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

// Plain unit tests: the controller is created directly, no Spring context needed, so they run in milliseconds.
@DisplayName("Controller")
class ControllerTest {

    private final Controller controller = new Controller();

    @Test
    @DisplayName("test endpoint returns the greeting")
    void returnsGreeting() {
        assertThat(controller.getMethodName()).isEqualTo("Hello from Analyzer Service!");
    }

    @Test
    @DisplayName("greeting is never blank")
    void greetingIsNotBlank() {
        assertThat(controller.getMethodName()).isNotBlank();
    }

    @Test
    @DisplayName("greeting mentions the service name")
    void greetingMentionsService() {
        assertThat(controller.getMethodName()).containsIgnoringCase("analyzer service");
    }

    @Test
    @DisplayName("pipeline sanity check")
    void sanityCheck() {
        assertThat(1 + 1).isEqualTo(2);
    }
}
