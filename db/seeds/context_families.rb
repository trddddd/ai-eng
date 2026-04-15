# Context families seed data (ADR-002)
# Consolidated flat list ~17 context families for sense classification

FAMILIES = [
  { name: "people & relationships", description: "Люди, группы, социальные взаимодействия" },
  { name: "communication", description: "Речь, язык, передача информации" },
  { name: "body & health", description: "Тело, здоровье, физические функции" },
  { name: "food & drink", description: "Еда, питьё, потребление" },
  { name: "movement & sports", description: "Движение, спорт, соревнования" },
  { name: "thinking & knowledge", description: "Мышление, знание, обучение" },
  { name: "emotions & feelings", description: "Чувства, эмоции, мотивация" },
  { name: "objects & tools", description: "Предметы, инструменты, технологии" },
  { name: "nature & environment", description: "Природа, животные, растения" },
  { name: "places & travel", description: "Места, география, путешествия" },
  { name: "time & events", description: "Время, события, изменения" },
  { name: "actions & activities", description: "Действия, создание, активности" },
  { name: "possession & commerce", description: "Владение, торговля, финансы" },
  { name: "physical interaction", description: "Физический контакт, восприятие" },
  { name: "weather", description: "Погода, климатические явления" },
  { name: "qualities & states", description: "Абстрактные качества, состояния, формы" },
  { name: "unknown", description: "Fallback: прилагательные/наречия, function words" }
].freeze

ContextFamily.insert_all(FAMILIES) if ContextFamily.none? # rubocop:disable Rails/SkipsModelValidations
