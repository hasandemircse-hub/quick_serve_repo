package com.quickserve.backend.data;

import com.quickserve.backend.model.*;
import com.quickserve.backend.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;

@Component
public class DataLoader implements CommandLineRunner {

    @Value("${app.frontend-url}")
    private String frontendUrl;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TableRepository tableRepository;

    @Autowired
    private MenuItemRepository menuItemRepository;

    @Override
    public void run(String... args) throws Exception {
        loadUsers();
        loadTables();
        loadMenuItems();
    }

    private void loadUsers() {
        if (userRepository.count() > 0) return;

        // Garson
        User waiter1 = new User();
        waiter1.setUsername("garson1");
        waiter1.setPassword("password123");
        waiter1.setEmail("garson1@quickserve.com");
        waiter1.setRole(UserRole.WAITER);
        userRepository.save(waiter1);

        // Patron/Manager
        User manager = new User();
        manager.setUsername("patron");
        manager.setPassword("password123");
        manager.setEmail("patron@quickserve.com");
        manager.setRole(UserRole.MANAGER);
        userRepository.save(manager);

        // Aşçı
        User chef = new User();
        chef.setUsername("asci");
        chef.setPassword("password123");
        chef.setEmail("asci@quickserve.com");
        chef.setRole(UserRole.CHEF);
        userRepository.save(chef);

        // Kalfa
        User assistantChef = new User();
        assistantChef.setUsername("kalfa");
        assistantChef.setPassword("password123");
        assistantChef.setEmail("kalfa@quickserve.com");
        assistantChef.setRole(UserRole.ASSISTANT_CHEF);
        userRepository.save(assistantChef);
    }

    private void loadTables() {
        if (tableRepository.count() > 0) return;

        for (int i = 1; i <= 8; i++) {
            RestaurantTable table = new RestaurantTable();
            table.setTableNumber(i);
            table.setCapacity(4);
            table.setStatus(TableStatus.EMPTY);
            table.setQrCode("");
            RestaurantTable saved = tableRepository.save(table);
            saved.setQrCode(frontendUrl + "/table/" + saved.getId());
            tableRepository.save(saved);
        }
    }

    private void loadMenuItems() {
        if (menuItemRepository.count() > 0) return;

        // Mezeler
        MenuItem mezze1 = new MenuItem();
        mezze1.setName("Hummus");
        mezze1.setDescription("Nohuttan yapılan sos");
        mezze1.setPrice(new BigDecimal("50.00"));
        mezze1.setAvailable(true);
        menuItemRepository.save(mezze1);

        MenuItem mezze2 = new MenuItem();
        mezze2.setName("Baba Ganoush");
        mezze2.setDescription("Patlıcandan yapılan sos");
        mezze2.setPrice(new BigDecimal("55.00"));
        mezze2.setAvailable(true);
        menuItemRepository.save(mezze2);

        // Ana Yemekler
        MenuItem mainCourse1 = new MenuItem();
        mainCourse1.setName("Adana Kebab");
        mainCourse1.setDescription("Kıyma kebab pirinç ile");
        mainCourse1.setPrice(new BigDecimal("150.00"));
        mainCourse1.setAvailable(true);
        menuItemRepository.save(mainCourse1);

        MenuItem mainCourse2 = new MenuItem();
        mainCourse2.setName("Şiş Kebab");
        mainCourse2.setDescription("Kuzu eti şiş kebab");
        mainCourse2.setPrice(new BigDecimal("180.00"));
        mainCourse2.setAvailable(true);
        menuItemRepository.save(mainCourse2);

        // Tatlılar
        MenuItem dessert1 = new MenuItem();
        dessert1.setName("Baklava");
        dessert1.setDescription("Fıstıklı baklava");
        dessert1.setPrice(new BigDecimal("40.00"));
        dessert1.setAvailable(true);
        menuItemRepository.save(dessert1);

        MenuItem dessert2 = new MenuItem();
        dessert2.setName("Künefe");
        dessert2.setDescription("Peynirli kunefe");
        dessert2.setPrice(new BigDecimal("45.00"));
        dessert2.setAvailable(true);
        menuItemRepository.save(dessert2);

        // İçecekler
        MenuItem drink1 = new MenuItem();
        drink1.setName("Çay");
        drink1.setDescription("Sıcak çay");
        drink1.setPrice(new BigDecimal("15.00"));
        drink1.setAvailable(true);
        menuItemRepository.save(drink1);

        MenuItem drink2 = new MenuItem();
        drink2.setName("Ayran");
        drink2.setDescription("Soğuk ayran");
        drink2.setPrice(new BigDecimal("20.00"));
        drink2.setAvailable(true);
        menuItemRepository.save(drink2);
    }
}
