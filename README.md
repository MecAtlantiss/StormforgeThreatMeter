# Stormforge Threat Meter (STM)
A threat meter addon for Stormforge TBC private servers.

<span style="color: #f03c15">This addon only works on Stormforge TBC servers.</span>

# Why STM over Omen/DTM?
Unlike Omen and DTM, which have to read the player's combat log events to estimate threat, Stormforge Threat Meter receives accurate threat data from the game server. This makes STM better able to reliably handle events that Omen and DTM tend to struggle with, such as threat resets on bosses (e.g. Illidan phase 3/4/5). Unlike Omen, this addon doesn't require other players in your party/raid to also have it installed. The addon is also less computationally intensive than DTM, so players won't experience lag on fights with many mobs.

# Installation

Step 1. [Download the ZIP file of the lastest release here.](https://github.com/MecAtlantiss/StormforgeThreatMeter/releases/latest)

Step 2. Inside the ZIP file you've just downloaded is a folder named "StormforgeThreatMeter-1.3". Inside of that folder is another folder named "StormforgeThreatMeter" (without a version number in the name). Extract this "StormforgeThreatMeter" folder from the ZIP file and put it into your `Interface/Addons/` folder in your World of Warcraft directory.

If the addon doesn't appear in-game, then you likely put the wrong folder into your Addons folder.

# How to use

When you log in, you should see a black frame near the middle of your screen. You drag this around with your left mouse. When the frame is unlocked, you can re-size it by dragging the bottom left corner around.

#### You also can use the following chat commands while in-game
---
`/stm` This will give you a list of the available commands.  
`/stm lock` This will toggle between locking and unlocking the meter's frame.  
`/stm warnThreshold` This allows you to change the threat threshold at which a warning sound is played. You could, for example, type `/stm warnThreshold 90` to change the threshold to 90%. Players in melee range will pull aggro when they're at 110% of the current aggro target's threat and players out of melee range will pull at 130% threat. By default, the addon is set to play a sound when you exceed 115% threat. The sound will not play if you're on a character specialized to be a tank. You can also type `/stm warnThreshold 0` to disable the sound from ever playing.  
`/stm toggleClassIcons` This will toggle between showing or hiding class icons next to the threat bars.

#### What the threat bar colors mean  
---
The player's bar is colored green when they don't have aggro.  
The player's bar is colored teal when they have aggro.  
The bar of someone else with aggro is blue.  

# Upcoming features

The following are features that I'd like to eventually add to the threat meter:
* AoE mode: 
* Ability to better cusutomize how the meter looks (e.g. font size and bar height)

#  Credits

Thank you to Wolfenstein, the lead developer of Stormforge TBC private servers, for making the threat data available to players.
