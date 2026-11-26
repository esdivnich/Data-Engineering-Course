-- final_script.sql
-- Итоговый скрипт для сдачи: создание сырой таблицы user_events в ClickHouse
-- Хранит события пользователей с автоматическим удалением через 30 дней

CREATE TABLE IF NOT EXISTS user_events (
    user_id UInt32,
    event_type String, -- тип действия пользователя
    points_spent UInt32, -- баллы
    event_time DateTime -- время действия
) ENGINE = MergeTree()
ORDER BY (event_time, user_id) -- пачки по event_time, в которых сортировки по user_id
TTL event_time + INTERVAL 30 DAY; -- хранение +30 дней от event_time, затем удаление

CREATE TABLE IF NOT EXISTS user_events_agg (
    event_date Date, -- дата события (без времени)
    event_type String, -- тип действия
    unique_users AggregateFunction(uniq, UInt32), -- тип данных в колонке "unique_users": состояние уникальных пользователей по дате и по event_type
    total_spent AggregateFunction(sum, UInt32), -- тип данных в колонке "total_spent": состояние суммы списанных баллов по всем пользователям для данной даты и типа действия, которое потом будет слито через sumMerge
    total_action AggregateFunction(count, UInt32) -- тип данных в колонке "total_action": состояние количества действий по event_type пользователями
) ENGINE = AggregatingMergeTree()
ORDER BY (event_date,event_type)
TTL event_date + INTERVAL 180 DAY; --хранение агрегированных данных 180 дней

CREATE MATERIALIZED VIEW user_events_mv TO user_events_agg AS
SELECT
    toDate(event_time) AS event_date, -- преобразует дату и время только в дату
    event_type,
    uniqState(user_id) AS unique_users,
    sumState(points_spent) AS total_spent,
    countState() AS total_action -- готовит состояние для подсчета количества строк по event_type в определнную дату (согласно группировке)
FROM user_events
GROUP BY event_date, event_type;

INSERT INTO user_events VALUES
(1, 'login', 0, now() - INTERVAL 10 DAY), -- События 10 дней назад
(2, 'signup', 0, now() - INTERVAL 10 DAY),
(3, 'login', 0, now() - INTERVAL 10 DAY),
(1, 'login', 0, now() - INTERVAL 7 DAY), -- События 7 дней назад
(2, 'login', 0, now() - INTERVAL 7 DAY),
(3, 'purchase', 30, now() - INTERVAL 7 DAY),
(1, 'purchase', 50, now() - INTERVAL 5 DAY), -- События 5 дней назад
(2, 'logout', 0, now() - INTERVAL 5 DAY),
(4, 'login', 0, now() - INTERVAL 5 DAY),
(1, 'login', 0, now() - INTERVAL 3 DAY), -- События 3 дня назад
(3, 'purchase', 70, now() - INTERVAL 3 DAY),
(5, 'signup', 0, now() - INTERVAL 3 DAY),
(2, 'purchase', 20, now() - INTERVAL 1 DAY), -- События вчера
(4, 'logout', 0, now() - INTERVAL 1 DAY),
(5, 'login', 0, now() - INTERVAL 1 DAY),
(1, 'purchase', 25, now()), -- События сегодня
(2, 'login', 0, now()),
(3, 'logout', 0, now()),
(6, 'signup', 0, now()),
(6, 'purchase', 100, now());

WITH
    signup_events AS ( -- создать временный справочник с названием signup_events с содержимым:
        -- Шаг 1: Создаём справочник — кто и когда впервые зарегистрировался
        SELECT
            user_id,
            min(toDate(event_time)) AS signup_date -- мин.дата и время, преобразованное в дату
        FROM user_events
        WHERE event_type = 'signup'
        GROUP BY user_id
    ),
    new_events AS ( -- создать второй временный справочник с названием new_events с содержимым:
        -- Шаг 2: Прилепляем дату регистрации на все события + считаем дни
        SELECT
            se.signup_date,
            ue.user_id AS user_id,           -- явно говорим: в этой таблице колонка называется user_id
            dateDiff('day', se.signup_date, toDate(ue.event_time)) AS days_since_signup
        FROM signup_events AS se
        JOIN user_events AS ue ON se.user_id = ue.user_id
    )
-- Шаг 3: Считаем метрики Retention 7days
SELECT
    signup_date AS total_users_day_0,
    uniqIf(user_id, days_since_signup BETWEEN 1 AND 7) AS returned_in_7_days,
    round(uniqIf(user_id, days_since_signup BETWEEN 1 AND 7) * 100.0 / uniq(user_id), 2) AS retention_7d_percent
FROM new_events AS ne
GROUP BY ne.signup_date
ORDER BY ne.signup_date;

SELECT
    event_date,
    event_type,
    uniqMerge(unique_users) AS unique_users_final,
    sumMerge(total_spent) AS total_spent_final,
    countMerge(total_action) AS total_actions_final
FROM user_events_agg
GROUP BY event_date, event_type
ORDER BY event_date, event_type;


