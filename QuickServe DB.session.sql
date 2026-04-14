-- Superadmin kullanıcı adını ve şifresini güncelle
UPDATE users SET
    username = 's',
    password = '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'
WHERE username = 'superadmin';

-- Eğer username unique constraint hatası alırsanız, önce eski kullanıcıyı silip yeni oluşturun
-- DELETE FROM users WHERE username = 'superadmin';
-- INSERT INTO users (username, password, full_name, role, is_active, created_at)
-- VALUES ('s', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Superadmin', 'SUPERADMIN', true, NOW());