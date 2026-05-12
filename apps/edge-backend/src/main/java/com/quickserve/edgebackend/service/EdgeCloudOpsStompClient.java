package com.quickserve.edgebackend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.converter.StringMessageConverter;
import org.springframework.messaging.simp.stomp.StompFrameHandler;
import org.springframework.messaging.simp.stomp.StompHeaders;
import org.springframework.messaging.simp.stomp.StompSession;
import org.springframework.messaging.simp.stomp.StompSessionHandlerAdapter;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;
import org.springframework.web.socket.sockjs.client.SockJsClient;
import org.springframework.web.socket.sockjs.client.WebSocketTransport;

import java.lang.reflect.Type;
import java.util.List;

/**
 * Cloud STOMP: {@code edge_ops} (ops pull) ve {@code edge_master} (snapshot yenileme).
 */
@Component
@ConditionalOnProperty(name = "app.edge.cloud-ws-enabled", havingValue = "true")
public class EdgeCloudOpsStompClient {

    private static final Logger log = LoggerFactory.getLogger(EdgeCloudOpsStompClient.class);

    private final CloudBridgeService cloudBridgeService;
    private final EdgeOpsPullService edgeOpsPullService;
    private final EdgeBootstrapSyncService edgeBootstrapSyncService;

    @Value("${app.edge.restaurant-id:0}")
    private long restaurantId;

    public EdgeCloudOpsStompClient(
            CloudBridgeService cloudBridgeService,
            EdgeOpsPullService edgeOpsPullService,
            EdgeBootstrapSyncService edgeBootstrapSyncService
    ) {
        this.cloudBridgeService = cloudBridgeService;
        this.edgeOpsPullService = edgeOpsPullService;
        this.edgeBootstrapSyncService = edgeBootstrapSyncService;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void startBackground() {
        Thread.ofVirtual().start(this::runLoop);
    }

    private void runLoop() {
        while (!Thread.currentThread().isInterrupted()) {
            try {
                runOneSession();
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                break;
            } catch (Exception ex) {
                log.warn("edge STOMP: {}", ex.getMessage());
            }
            try {
                Thread.sleep(15_000);
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }

    private void runOneSession() throws Exception {
        if (restaurantId <= 0 || !cloudBridgeService.shouldTryCloudLive()) {
            Thread.sleep(5_000);
            return;
        }
        StandardWebSocketClient wsClient = new StandardWebSocketClient();
        SockJsClient sockJsClient = new SockJsClient(List.of(new WebSocketTransport(wsClient)));
        WebSocketStompClient stompClient = new WebSocketStompClient(sockJsClient);
        stompClient.setMessageConverter(new StringMessageConverter());

        String url = cloudBridgeService.getCloudBaseUrl() + "/ws";
        WebSocketHttpHeaders wsHeaders = new WebSocketHttpHeaders();
        cloudBridgeService.stampAuth(wsHeaders);
        StompHeaders stompHeaders = new StompHeaders();

        StompSessionHandlerAdapter handler = new StompSessionHandlerAdapter() {
            @Override
            public void afterConnected(StompSession session, StompHeaders connectedHeaders) {
                String opsTopic = "/topic/restaurant/" + restaurantId + "/edge_ops";
                session.subscribe(opsTopic, new StompFrameHandler() {
                    @Override
                    public Type getPayloadType(StompHeaders headers) {
                        return String.class;
                    }

                    @Override
                    public void handleFrame(StompHeaders headers, Object payload) {
                        edgeOpsPullService.pullAfterWsHint();
                    }
                });
                log.info("edge STOMP subscribed {}", opsTopic);

                String masterTopic = "/topic/restaurant/" + restaurantId + "/edge_master";
                session.subscribe(masterTopic, new StompFrameHandler() {
                    @Override
                    public Type getPayloadType(StompHeaders headers) {
                        return String.class;
                    }

                    @Override
                    public void handleFrame(StompHeaders headers, Object payload) {
                        Thread.ofVirtual().start(() -> {
                            boolean ok = edgeBootstrapSyncService.pullSnapshotFromCloud();
                            log.info("edge_master → snapshot pull {}", ok ? "ok" : "skipped/failed");
                        });
                    }
                });
                log.info("edge STOMP subscribed {}", masterTopic);
            }
        };

        StompSession session = stompClient.connectAsync(url, wsHeaders, stompHeaders, handler).get();
        while (session.isConnected()) {
            Thread.sleep(2_000);
        }
        log.info("edge STOMP disconnected");
    }
}
