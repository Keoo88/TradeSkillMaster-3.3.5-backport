<p align="center">
  <img src="https://tradeskillmaster.com/logo.png" alt="TradeSkillMaster" width="120">
</p>

<p align="center">
  <b><span style="color:red">⚠ WARNING: This addon is in BETA — may contain bugs and incomplete features ⚠</span></b>
</p>

<br>

<p align="center">
  <img src="https://img.shields.io/badge/TSM-v4.14.66-ff8800?style=for-the-badge&logo=appveyor">
  <img src="https://img.shields.io/badge/WotLK-3.3.5a-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/status-beta-red?style=for-the-badge">
</p>

<h1 align="center">TradeSkillMaster — WotLK 3.3.5a backport</h1>

<p align="center">
  <b>The complete TradeSkillMaster suite for World of Warcraft 3.3.5a (WotLK).</b><br>
  <i>Backport of TradeSkillMaster v4.14.66 to the WoW 3.3.5a client.</i>
</p>

<p align="center">
  <a href="#english">English</a> ·
  <a href="#russian">Русский</a>
</p>

---

<a name="english"></a>
## English

<p align="center">
  <a href="#modules">Modules</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#credits">Credits</a>
</p>

### About

**TradeSkillMaster (TSM)** is an all-in-one suite for the in-game economy:
auction house scanning, bulk posting, crafting management, mailing, group-based
automation, and more. This repository is a **backport of TSM v4.14.66**
to the **WoW 3.3.5a (WotLK)** client.

<a name="modules"></a>
### Modules

#### Auction House

<img width="834" height="588" alt="auction-house" src="https://github.com/user-attachments/assets/04c11435-5bb2-4609-8100-3b93da5a9384" />

The central hub for everything auction-related. Scan the entire auction house,
browse current listings, and search for specific items or whole groups. Both a
fast full-scan and targeted searches are built right into the AH window.

#### Auctioning

<img width="831" height="586" alt="auctioning" src="https://github.com/user-attachments/assets/d33addb2-416d-40c2-a27e-f9241233a647" />

Bulk-post your items for sale. A single Post Scan walks through your groups,
applies your auctioning operations (pricing, undercut, stack size, duration),
and posts everything for you — no more posting auctions one by one.

#### Crafting

<img width="822" height="589" alt="crafting" src="https://github.com/user-attachments/assets/32f788ae-b193-4774-9bfd-3768be1125a4" />

Manage your professions and crafting queue. Track recipes and reagents, queue
up what you want to make, and see the expected crafting profit so you always
know which crafts are worth selling.

#### Dashboard

<img width="902" height="702" alt="Dashboard" src="https://github.com/user-attachments/assets/1312d48f-a8da-45e8-8e15-c35f39e4bacc" />

The main overview screen. At-a-glance summaries and charts of your activity —
gold, sales, and the key numbers you care about, all in one place.

#### Destroying

<img width="295" height="443" alt="destroying" src="https://github.com/user-attachments/assets/a6608ce0-dc40-4e8e-aefb-55e004a19d48" />

Disenchant, mill, and prospect items in bulk. Set up groups and operations and
let TSM process stacks of materials quickly instead of doing it by hand.

#### Groups

<img width="903" height="706" alt="groups" src="https://github.com/user-attachments/assets/a999cd20-8471-490d-91be-147f3732c0ef" />

The heart of TSM. Organize your items into groups and attach operations
(auctioning, shopping, crafting, mailing, etc.) so every other module knows
exactly how to treat each item.

#### Mailing

<img width="621" height="519" alt="Mailing" src="https://github.com/user-attachments/assets/1b73fda9-e164-4d3b-8dfc-18b60c94ff2f" />

Send and collect mail in bulk. Move items and gold between your characters
based on your groups, and empty your mailbox with a single click.

<a name="installation"></a>
### Installation

1. Download the latest release (or clone this repository).
2. Extract the archive.
3. **Important:** the archive contains **7 addon folders**. Move **all** of them into:
   ```
   \Interface\AddOns\
   ```
4. Enable them on the character-select AddOns screen and launch the game. Type `/tsm` to open.

### Compatibility

- Built and tested on **Warmane** (WoW 3.3.5a, Interface `30300`).
- Developed exclusively for **Warmane**. I am not responsible for functionality on other servers.

<a name="credits"></a>
### Credits

- Original addon: **TradeSkillMaster Team**
- WotLK 3.3.5a backport: **Keoo**

---

<a name="russian"></a>
## Русский

<p align="center">
  <a href="#модули">Модули</a> ·
  <a href="#установка">Установка</a> ·
  <a href="#благодарности">Благодарности</a>
</p>

### Об аддоне

**TradeSkillMaster (TSM)** — это комплексный набор инструментов для внутриигровой
экономики: сканирование аукциона, массовое выставление лотов, управление
профессиями, рассылка почты, автоматизация на основе групп и многое другое.
Этот репозиторий — **бэкпорт TSM v4.14.66** под клиент
**WoW 3.3.5a (WotLK)**.

<a name="модули"></a>
### Модули

#### Аукцион (Auction House)

<img width="834" height="588" alt="auction-house" src="https://github.com/user-attachments/assets/04c11435-5bb2-4609-8100-3b93da5a9384" />

Главный центр всего, что связано с аукционом. Сканируйте весь аукцион,
просматривайте текущие лоты и ищите конкретные предметы или целые группы.
Быстрое полное сканирование и точечный поиск встроены прямо в окно аукциона.

#### Выставление лотов (Auctioning)

<img width="831" height="586" alt="auctioning" src="https://github.com/user-attachments/assets/d33addb2-416d-40c2-a27e-f9241233a647" />

Массовое выставление предметов на продажу. Одно сканирование (Post Scan)
проходит по вашим группам, применяет операции аукциониста (цена, undercut,
размер стака, длительность) и выставляет всё за вас — больше не нужно постить
лоты по одному.

#### Крафт (Crafting)

<img width="822" height="589" alt="crafting" src="https://github.com/user-attachments/assets/32f788ae-b193-4774-9bfd-3768be1125a4" />

Управление профессиями и очередью крафта. Отслеживайте рецепты и реагенты,
ставьте в очередь то, что хотите создать, и видьте ожидаемую прибыль от крафта —
вы всегда знаете, что выгодно делать на продажу.

#### Панель (Dashboard)

<img width="902" height="702" alt="Dashboard" src="https://github.com/user-attachments/assets/1312d48f-a8da-45e8-8e15-c35f39e4bacc" />

Главный обзорный экран. Сводки и графики вашей активности с первого взгляда —
золото, продажи и ключевые показатели в одном месте.

#### Распыление (Destroying)

<img width="295" height="443" alt="destroying" src="https://github.com/user-attachments/assets/a6608ce0-dc40-4e8e-aefb-55e004a19d48" />

Массовое распыление, размол и огранка предметов. Настройте группы и операции —
и TSM быстро обработает стаки материалов вместо ручной работы.

#### Группы (Groups)

<img width="903" height="706" alt="groups" src="https://github.com/user-attachments/assets/a999cd20-8471-490d-91be-147f3732c0ef" />

Сердце TSM. Организуйте предметы в группы и привязывайте к ним операции
(аукцион, закупка, крафт, почта и т.д.), чтобы каждый модуль точно знал, как
обращаться с каждым предметом.

#### Почта (Mailing)

<img width="621" height="519" alt="Mailing" src="https://github.com/user-attachments/assets/1b73fda9-e164-4d3b-8dfc-18b60c94ff2f" />

Массовая отправка и сбор почты. Перемещайте предметы и золото между своими
персонажами на основе групп и опустошайте почтовый ящик одним кликом.

<a name="установка"></a>
### Установка

1. Скачайте последний релиз (или клонируйте репозиторий).
2. Распакуйте архив.
3. **Важно:** архив содержит **7 папок аддонов**. Переместите **все** в:
   ```
   \Interface\AddOns\
   ```
4. Включите их на экране выбора персонажа и запустите игру. Введите `/tsm`, чтобы открыть.

### Совместимость

- Собрано и протестировано на **Warmane** (WoW 3.3.5a, Interface `30300`).
- Разрабатывалось исключительно для **Warmane**. За работоспособность на других серверах ответственности не несу.

<a name="благодарности"></a>
### Благодарности

- Оригинальный аддон: **Команда TradeSkillMaster**
- Бэкпорт под WotLK 3.3.5a: **Keoo**
