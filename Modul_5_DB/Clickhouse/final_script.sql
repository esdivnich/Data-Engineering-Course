-- final_script.sql
-- Итоговый скрипт для сдачи: создание сырой таблицы user_events в ClickHouse
-- Хранит события пользователей с автоматическим удалением через 30 дней

CREATE TABLE user_events (
    user_id UInt32,
    event_type String,
    points_spent UInt32,
    event_time DateTime
) ENGINE = MergeTree()
ORDER BY (event_time, user_id) -- пачки по event_time, в которых сортировки по user_id
TTL event_time + INTERVAL 30 DAY; -- хранение +30 дней от event_time, затем удаление


