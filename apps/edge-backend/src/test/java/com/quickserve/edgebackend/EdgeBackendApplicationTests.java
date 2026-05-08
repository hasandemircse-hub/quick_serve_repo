package com.quickserve.edgebackend;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = {
        "EDGE_SQLITE_PATH=./target/edge-test.db"
})
class EdgeBackendApplicationTests {

    @Test
    void contextLoads() {
    }
}
