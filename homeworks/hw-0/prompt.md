# HW-0: Промпт для агента

Инициализируй ruby on rails проект Rails 8, PostgreSQL (docker compose), Rspec, Redis (docker compose), Tailwind CSS и Hotwire (Turbo + Stimulus). Базовый язык интерфейса и контента по
умолчанию — русский; сразу заложи i18n (ключи в YAML, без захардкоженных пользовательских строк в коде).

Интервальное повторение: используй FSRS из репозитория open-spaced-repetition/rb-fsrs.

Доменная модель (минимум): пользователь используя has_secure_password, email, timestamps с минимальным набором валидаций, залогиниться можно только по email и паролю.

Качество: Следуй соглашениям Rails, rubocop, не раздувай архитектуру сверх описанного.

Используя playwright проверь работоспособность проекта.