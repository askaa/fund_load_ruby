Fund Load Limits — Ruby

Утилита обрабатывает попытки пополнения счёта из NDJSON-входа и печатает для каждой строки решение {accepted:true|false} согласно правилам.

Правила

База (per customer):

В день: суммарно ≤ $5,000

В ISO-неделю (cwyear/cweek): суммарно ≤ $20,000

В день: не более 3 попыток

Дополнительно (включено по умолчанию):

Monday rule: в понедельник сумма для проверок считается как amount × 2.

Prime-ID rule (глобально, не per customer):

В календарный день может быть принята только одна транзакция, у которой id — простое число.

Её эффективная сумма (с учётом Monday ×2) должна быть ≤ $9,999.


Деньги считаются в центах (целые числа) — это исключает ошибки округления float.

Запуск
bundle install
ruby main.rb input.txt > output.jsonl
# или
bin/run input.txt > output.jsonl


Формат входа (NDJSON):

{"id":"1","customer_id":"1","load_amount":"$100.00","time":"2025-10-14T10:00:00Z"}
{"id":"2","customer_id":"1","load_amount":"$5000.00","time":"2025-10-14T11:00:00Z"}


Формат выхода:

{"id":"1","customer_id":"1","accepted":true}
{"id":"2","customer_id":"1","accepted":false}

Тесты
bundle exec rspec


Покрытие: дневной лимит (сумма/кол-во), недельный лимит (в т.ч. граница ISO-недели на стыке годов), Monday ×2, Prime-ID ≤ 9999, точность центов.

Конфигурация правил

В main.rb:

processor = FundProcessor.new(
  enable_prime_rule:  true,
  enable_monday_rule: true
)

Структура проекта
fund_load_ruby/
├── Gemfile
├── README.md
├── main.rb
├── lib/
│   ├── fund_processor.rb
│   ├── limit_tracker.rb
│   ├── models.rb
│   └── utils.rb
└── spec/
    ├── spec_helper.rb
    └── fund_processor_spec.rb

Assumptions

Вход — корректный NDJSON; пустые строки игнорируются.

Все проверки выполняются относительно UTC (time — ISO-8601).

Недели — ISO (cwyear/cweek).

Если id нечисловой — не считается простым (prime).

Обработка идёт в порядке строк; состояние хранится в памяти процесса.
