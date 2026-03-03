UPDATE users
SET active = 1,
    role = 'admin',
    pinHash = '081deeaf5760944baf5aa19524a1601598541610b50e910b3495d933bdf7bbc3'
WHERE LOWER(email) = 'ayslan@gmail.com';

SELECT id, name, email, active, role FROM users WHERE LOWER(email) = 'ayslan@gmail.com';
