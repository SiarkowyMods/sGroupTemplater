sGroupTemplater
===============

Provides group template functionality. Usage: `/sgt`

Supports World of Warcraft patch 2.4.3 only.

Usage
-----

These are the available slash commands. All of these can also be accessed through
the graphical interface under `/sgt gui` or through the in-game options pane.

`T` is the template name and has a value of `Default` if not provided.

* `/sgt save T` — Saves the group template under name `T`.
* `/sgt disband` — Disbands the group. Make sure you did `/sgt save` before!
* `/sgt restore T` — Performs a full restore from template `T`.

Restoring consists of the following steps, which can also be issued individually:

* `/sgt invite T` — Invites players from template who are outside of your current group.
* `/sgt shuffle T` — Shuffles players between subgroups according to the template.
* `/sgt assistants T` — Promotes assistants.
* `/sgt loot T` — Sets proper looting method and threshold.
* `/sgt leader T` — Promotes new leader according to the template.

Additional commands:

* `/sgt move <player> <group>` — Moves player to specified group.
* `/sgt remote shuffler <name>` — The remote group shuffler.
* `/sgt gui` — Displays the graphical interface.

Repartying
----------

These are the steps that have to be done in order to do repartying.

Slash command method:

* Remove offline and AFK players from raid.
* Save group template (leader is not needed): `/sgt save`
* Disband the group (you have to be the leader): `/sgt disband`
* Restore template when disband finished: `/sgt restore`

Graphical interface:

* Open the GUI: `/sgt gui`
* Remove offline and AFK players from raid.
* Place the cursor in the New template input box and press Enter. This will
  save the group template under the name of `Default`.
* Press the Disband group button.
* Make sure the Select template menu points to the `Default` template.
* Finally press the Restore button and wait for the process to finish.

Of course you can repeat the whole process using other template name if needed.

Installation
------------

* Download sGroupTemplater using the `Download ZIP` button on the right (or by cloning the repository using `Git`).
* Open the ZIP file and copy contents of `sGroupTemplater-master` folder to your `Wow\Interface\AddOns` directory.
* Restart the game client, log into the game and ensure that sGroupTemplater is present on the addon list.

Screen shots
------------

![GUI](http://siarkowy.net/img/sgt1.jpg)

_GUI under `/sgt gui`._

![Binds](http://siarkowy.net/img/sGT-1.3.png)

_Bindings pane_
