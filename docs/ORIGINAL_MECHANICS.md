Anthony
Branched world generation: The world will be procedurally generated consisting of 5 total arenas and 4 special rooms. These rooms are arenas, rest sites, shops, and mystery rooms. The rooms will alternate from special rooms to combat rooms. Out of the three special rooms, only two are spawning giving each a 66% chance of appearing after combat. To select the room you want to go to, the player must walk through one of the doorways that appears after a combat ends. The doors close after the player walks through and gives them the option only to progress to a combat room after.
Purchasing/Selling: The player can exchange their currency to buy items to add to their inventory. They can also exchange their items to get currency (the shop will give the player 50% of the items brand new value). The player will use their mouse to look at each item in their inventory and the shop and make selections by left clicking. There will be buttons present that lets the player choose to buy, sell or leave. The cost of items scale with its rarity. Each tier of rarity increases its cost by an additional 25% from the base (ex: common 100, uncommon 125, rare 150, epic, 175, legendary 200)
Resting: At resting site rooms there will be a sleeping bag, a campfire, and a workbench. The player will have to choose one of the three to walk up to and press E to sleep at the sleeping bag and heal for 50% of their maximum health, upgrade one of their stats by 20% (ex: increase speed by 20%), or upgrade an eligible item’s mastery progression by 20XP
Mystery Rooms: Mystery rooms are activated as soon as the player enters them and they shuffle through multiple different things (each with a 20% chance of happening):
Another arena fighting room
A curse/debuff bestowed upon you (ex: -10% to a random stat you have)
Robbery: You lose 25% of your currency or a random item in your inventory
A buff bestowed upon you (ex: +10% to a random stat you have)
Finding a skeleton with a random item for you to take.
Jadin
1. RNG / Item Drop System
Input: No direct input is required. Item drops are automatically generated when an enemy is defeated.
Rules and Numbers:
When an enemy is defeated, it has a chance to drop an item that the player can collect. The item type and rarity are randomly determined using a probability-based loot system. Different enemy types have different drop chances and available loot pools.
Regular enemies have a 60% chance to drop an item.
Minibosses have a 100% chance to drop at least one item.
Bosses have a 100% chance to drop at least one item, including a guaranteed rare or higher rarity item.
When an item drops, its rarity is randomly determined using the following probabilities:
Common: 59%
Uncommon: 25%
Rare: 12%
Epic: 3%
Legendary: 1%
Bosses use a separate guaranteed rare-or-higher drop rule instead of the regular rarity distribution.
Items can include weapons, consumables, and upgrade materials. Higher-rarity items can have stronger effects, increased damage, or additional benefits.
How It Interacts With My Other Mechanic:
The RNG Item Drop System affects the Inventory System because the type and rarity of the generated drops determine what items the player can collect, store, equip, and use.
2. Inventory System
Input:
E – Pick up an item when standing within 2 meters of it.
Tab – Open or close the inventory.
Left Click – Select an item in the inventory.
Left Click on Equip/Use – Equip a weapon or use a consumable.
Left Click on Drop – Remove an item from the inventory and place it back into the world.
Rules and Numbers:
The player has an inventory with 12 available item slots. Each weapon occupies one slot and cannot be stacked. Consumable items and upgrade materials can stack up to 5 of the same item in one slot.
When an enemy drops an item, the player must walk within 2 meters of it and press E to collect it. The item is automatically placed into the first available inventory slot.
If the inventory is full, the player cannot collect additional items until they make room by using, selling, or dropping something.
The player can equip one weapon at a time from their inventory and switch between collected weapons. Consumable items can also be used directly from the inventory.
How It Interacts With My Other Mechanic:
The Inventory System affects the RNG Item Drop System because the player's available inventory space determines whether newly generated drops can be collected. If the inventory is full, the player must make room before collecting additional drops.

Evan
Enemies - (regular enemies, bosses, minibosses, final boss)
Its name, and the input that does it.
Enemies, if the player is visible or not, how it is attacked and how it attacks, what arena it is in from the arena mechanic.
The rules and the numbers.
Each enemy has 2 attacks and a set amount of health. It can only spawn in certain rooms and once health is 0, it must disappear.
Arena - (3 types of arenas with different mechanics and environments, boss room)
Its name, and the input that does it.
Arena takes in what is chosen from the branched world generation mechanic.
The rules and the numbers.
Each room has an individual mechanic whether it be lava or acid rooms with subtle stage hazards with enemies roaming. The stage determines what enemies can spawn in.
Michael
1. Combat System
Inputs:
Left Click – Light Attack
Right Click – Heavy Attack
Space – Dodge
F – Parry
Weapons:
Daggers: Fast, short range. 8–15 damage.
Swords: Balanced speed and range. 10–20 damage.
Greatswords: Slow, high damage. 18–30 damage.
Spears: Long range, moderate damage. 10–18 damage.
Rules and Numbers:
Players have 100 stamina, regenerating 15 per second.
Attacks consume 5–30 stamina depending on the weapon.
Dodging costs 15 stamina and provides 0.3 seconds of invincibility.
Parrying costs 10 stamina and staggers enemies for 1.5 seconds.
2. Weapon Mastery System
Input: Uses combat controls.
Rules and Numbers:
Defeating enemies grants 5 mastery XP for the equipped weapon.
At 25 XP, players unlock a new combo.
At 50 XP, players unlock a special attack costing 30 stamina.
Each weapon has its own mastery progression.
