# Vouchers Core

Create vouchers/codes that allow players to get vip, credits, various bonuses and privileges by using them. <br>
After using the voucher, the server executes the commands listed in the voucher.

Video preview - https://youtu.be/-_NG9xZpYUg
<br>Fully documentation - https://github.com/NockyCZ/Vouchers/wiki

### Features
1. Create a random or specific vouchers/codes
2. Vouchers can send multiple server commands
3. Variables can be used for commands (steamid32, steamid64, userid, username)
4. Ability to create vouchers with a specified lifetime, after which the voucher will be deleted
5. Ability to create vouchers with a given number of uses of one voucher (there is protection against reuse of the voucher by one player)
6. If the player writes the voucher/code wrong several times (vouchers_attempts), he will be blocked for specific time (vouchers_block_time)
7. Logging block/unblock/deletion/voucher usage in `sourcemod/logs/vouchers_core.txt`
