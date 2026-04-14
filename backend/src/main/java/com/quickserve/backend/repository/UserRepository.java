package com.quickserve.backend.repository;

import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.UserRole;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByUsername(String username);

    Optional<User> findByEmail(String email);

    List<User> findByRestaurantIdOrderByFullName(Long restaurantId);

    List<User> findByRestaurantIdAndRoleAndIsActiveTrue(Long restaurantId, UserRole role);

    List<User> findByRestaurantIdAndIsActiveTrue(Long restaurantId);

    boolean existsByUsername(String username);

    boolean existsByRestaurantIdAndRole(Long restaurantId, UserRole role);

    int countByRestaurantId(Long restaurantId);

    boolean existsByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.role = 'SUPERADMIN'")
    List<User> findAllSuperadmins();

    @Query("SELECT u FROM User u WHERE u.restaurant.id = :restaurantId " +
           "AND u.role IN ('WAITER', 'HEAD_WAITER') AND u.isActive = true AND u.isOnLeave = false")
    List<User> findActiveWaiters(@Param("restaurantId") Long restaurantId);

    @Modifying
    @Query("DELETE FROM User u WHERE u.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
