package com.quickserve.backend.edge;

import com.quickserve.backend.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.AfterReturning;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;

import java.lang.reflect.Method;

/**
 * Admin (ve mutfak menü stok) yazma işlemlerinden sonra edge snapshot yenilemesi için WS yayını.
 */
@Aspect
@Component
@Order
@RequiredArgsConstructor
@Slf4j
public class MasterDataSyncAspect {

    private final EdgeMasterDataChangedPublisher publisher;
    private final SecurityUtils securityUtils;

    @AfterReturning(
            pointcut = "within(com.quickserve.backend.controller.AdminController) && execution(public * *(..))",
            returning = "result"
    )
    public void afterAdminMutation(JoinPoint joinPoint, Object result) {
        Method method = ((MethodSignature) joinPoint.getSignature()).getMethod();
        if (!isMutatingHttpMethod(method)) {
            return;
        }
        try {
            Long rid = securityUtils.getCurrentRestaurantId();
            publisher.publish(rid, "admin." + method.getName());
        } catch (Exception e) {
            log.debug("edge_master skip after {}: {}", joinPoint.getSignature().toShortString(), e.getMessage());
        }
    }

    @AfterReturning(
            pointcut = "execution(* com.quickserve.backend.controller.KitchenController.setAvailability(..)) || "
                    + "execution(* com.quickserve.backend.controller.KitchenController.restoreAvailability(..))",
            returning = "result"
    )
    public void afterKitchenMenuAvailability(JoinPoint joinPoint, Object result) {
        Object[] args = joinPoint.getArgs();
        if (args.length > 0 && args[0] instanceof Long rid) {
            publisher.publish(rid, "kitchen.menu." + joinPoint.getSignature().getName());
        }
    }

    private static boolean isMutatingHttpMethod(Method method) {
        return AnnotatedElementUtils.hasAnnotation(method, PostMapping.class)
                || AnnotatedElementUtils.hasAnnotation(method, PutMapping.class)
                || AnnotatedElementUtils.hasAnnotation(method, DeleteMapping.class);
    }
}
