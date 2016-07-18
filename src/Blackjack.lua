-- Blackjack Game for ComputerCraft
-- by d4

-- Constants
ARCADE_MODE = 1
HIGHSCORE_MONITOR = 1
HIGHSCORE_MONITOR_PRIORITY_POSITION = "right"
ARTWORK_MONITOR = 1
ARTWORK_MONITOR_PRIORITY_POSITION = "top"
MAX_BET_FLAT = 100
MAX_BET_PERCENT = 50
START_MONEY = 500
NUMBER_OF_DECKS = 6
PLAYER_NAME_MAX_LENGTH = 12
IDLE_TIMEOUT_DELAY = 180
PROMPT_PREFIX="blackjack"
PRESS_ANY_KEY_DELAY = 0.3
DIRECTORY=".blackjack"
MAIN_MENU_ARTWORK = "logo.ccimg"
MONITOR_ARTWORK = "monitor_logo.ccimg"
GAMEOVER_ARTWORK = "game_over_nerd.ccimg"
HIGHSCORE_FILENAME = "highscore"

-- Initialize positions to use to find monitor
positions = {}
table.insert(positions, "right")
table.insert(positions, "left")
table.insert(positions, "top")
table.insert(positions, "bottom")
table.insert(positions, "back")
table.insert(positions, "front")

-- Initialize Deck
deck = {}
for i=1,NUMBER_OF_DECKS do
	table.insert(deck, "Ace of Diamonds")
	table.insert(deck, "Two of Diamonds")
	table.insert(deck, "Three of Diamonds")
	table.insert(deck, "Four of Diamonds")
	table.insert(deck, "Five of Diamonds")
	table.insert(deck, "Six of Diamonds")
	table.insert(deck, "Seven of Diamonds")
	table.insert(deck, "Eight of Diamonds")
	table.insert(deck, "Nine of Diamonds")
	table.insert(deck, "Ten of Diamonds")
	table.insert(deck, "Jack of Diamonds")
	table.insert(deck, "Queen of Diamonds")
	table.insert(deck, "King of Diamonds")
	table.insert(deck, "Ace of Clubs")
	table.insert(deck, "Two of Clubs")
	table.insert(deck, "Three of Clubs")
	table.insert(deck, "Four of Clubs")
	table.insert(deck, "Five of Clubs")
	table.insert(deck, "Six of Clubs")
	table.insert(deck, "Seven of Clubs")
	table.insert(deck, "Eight of Clubs")
	table.insert(deck, "Nine of Clubs")
	table.insert(deck, "Ten of Clubs")
	table.insert(deck, "Jack of Clubs")
	table.insert(deck, "Queen of Clubs")
	table.insert(deck, "King of Clubs")
	table.insert(deck, "Ace of Hearts")
	table.insert(deck, "Two of Hearts")
	table.insert(deck, "Three of Hearts")
	table.insert(deck, "Four of Hearts")
	table.insert(deck, "Five of Hearts")
	table.insert(deck, "Six of Hearts")
	table.insert(deck, "Seven of Hearts")
	table.insert(deck, "Eight of Hearts")
	table.insert(deck, "Nine of Hearts")
	table.insert(deck, "Ten of Hearts")
	table.insert(deck, "Jack of Hearts")
	table.insert(deck, "Queen of Hearts")
	table.insert(deck, "King of Hearts")
	table.insert(deck, "Ace of Spades")
	table.insert(deck, "Two of Spades")
	table.insert(deck, "Three of Spades")
	table.insert(deck, "Four of Spades")
	table.insert(deck, "Five of Spades")
	table.insert(deck, "Six of Spades")
	table.insert(deck, "Seven of Spades")
	table.insert(deck, "Eight of Spades")
	table.insert(deck, "Nine of Spades")
	table.insert(deck, "Ten of Spades")
	table.insert(deck, "Jack of Spades")
	table.insert(deck, "Queen of Spades")
	table.insert(deck, "King of Spades")
end
numberOfCards = 52 * NUMBER_OF_DECKS

-- Init local monitor size
width, height = term.getSize()

-- Init high score monitor settings
highscore = nil
highscore_name = nil
highscore_monitor = nil
highscore_monitor_enabled = HIGHSCORE_MONITOR

-- Init artwork monitor settings
artwork_monitor = nil
artwork_monitor_enabled = ARTWORK_MONITOR
artwork_monitor_image = nil

-- Init game variables
topOfDeck = 1
money = START_MONEY
playerHand = {}
dealerHand = {}

-- Useful split function
local function split( _sInput, _sDelimiter )
    local tReturn = {}
    local delimiter = string.gsub( _sDelimiter, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1" )
    local searchPattern = "([^"..delimiter.."]+)"..delimiter.."?"

    for match in string.gmatch( _sInput, searchPattern ) do
        table.insert( tReturn, match )
    end
    return tReturn
end

-- Press any key handler
function PressAnyKey()
	term.setCursorBlink(false)
	print("<Press any key to continue>")

	local events = {}
	local timoutTimer = os.startTimer(IDLE_TIMEOUT_DELAY)

	while true do
		events = { os.pullEvent() }
		if events[1] == "key" then
			os.sleep(PRESS_ANY_KEY_DELAY)
			term.setCursorBlink(true)
			return true
		elseif events[1] == 'timer' and events[2] == timoutTimer then
			return false
		end
	end
end

-- Read text handler
function readOrTimeout()
	local readWrapper = function()
												result = read()
												os.queueEvent('read', result)
											end

	co = coroutine.create(readWrapper)

	local events = {}

	local timoutTimer = os.startTimer(IDLE_TIMEOUT_DELAY)

	while true do
		if coroutine.status(co) ~= "dead" then
			coroutine.resume(co, unpack(events))
		end
		events = { os.pullEvent() }
		if events[1] == 'timer' and events[2] == timoutTimer then
			return nil
		elseif events[1] == 'read' then
			return events[2]
		end
	end
end

-- Creates a new highscore file if one was corrupted or didn't exist
function CreateNewHighScoreFile()
	local f = fs.open(DIRECTORY .. "/" .. HIGHSCORE_FILENAME, "w")
	f.write("0,nobody")
	f.close()
	highscore = 0
	highscore_name = "nobody"
end

-- Function to get high score from file and return it
function GetHighScore()
	-- Open the file for reading
	local f = fs.open(DIRECTORY .. "/" .. HIGHSCORE_FILENAME, "r")

	-- If the file doesn't exist we need to create it.
	if f == nil then
		CreateNewHighScoreFile()
		return
	end

	-- Read the score and name from the file and then close the file
	local input = f.readLine()
	f.close()

	-- If input is nil create new high score file.
	if input == nil then
		CreateNewHighScoreFile()
		return
	end

	-- Split input string into score and name
	local input_split = split(input, ',')
	local score = tonumber(input_split[1])
	local n = input_split[2]

	-- If the score is corrupt we need to create a new file.
	if score == nil or score < 0 then
		CreateNewHighScoreFile()
		return
	end

	-- Check if name is alphanumeric
	if string.match(n, "%W") ~= nil then
		CreateNewHighScoreFile()
		return
	end

	-- If we get this far, we have a valid score and can return it.
	highscore = score
	highscore_name = n
	f.close()

	-- High score has changed so print it again
	PrintHighScore()
end

function SetHighScore(_score, _name)
	local f = fs.open(DIRECTORY .. "/" .. HIGHSCORE_FILENAME, "w")
	f.write(_score .. "," .. _name)
	f.close()

	highscore = _score
	highscore_name = _name

	-- High score has changed so print it again
	PrintHighScore()
end

function PrintHighScore()
	local offset = nil

	-- If monitor is disabled we don't want to do this
	if highscore_monitor_enabled == 0 then
		return
	end

	-- Set monitor text size
	highscore_monitor.setTextScale(0.5)
	highscore_monitor.setCursorBlink(false)

	-- Clear monitor and print data
	highscore_monitor.clear()

	highscore_monitor.setCursorPos(1, 1)
	highscore_monitor.setBackgroundColor(colors.blue)
	highscore_monitor.setTextColor(colors.lime)
	highscore_monitor.write("   Black")
	highscore_monitor.setBackgroundColor(colors.red)
	highscore_monitor.setTextColor(colors.orange)
	highscore_monitor.write("jack   ")

	highscore_monitor.setCursorPos(1, 3)
	highscore_monitor.setBackgroundColor(colors.black)
	highscore_monitor.setTextColor(colors.white)
	highscore_monitor.write("     by d4     ")

	highscore_monitor.setCursorPos(1, 6)
	highscore_monitor.write("   High Score  ")

	offset = math.floor((14 - string.len(tostring(highscore))) / 2) + 1
	highscore_monitor.setCursorPos(offset, 7)
	highscore_monitor.write("$" .. highscore)

	offset = math.floor((12 - string.len(tostring(highscore_name))) / 2) + 1
	highscore_monitor.setCursorPos(offset, 8)
	highscore_monitor.write("by " .. highscore_name)
end

function PrintHand(hand)
	for i=1,#hand do
		print(" " .. hand[i])
	end
end

function GetCardValue(card)
	s = string.sub(card, 1, 2)
	if s == "Ac" then
		return 11
	elseif s == "Tw" then
		return 2
	elseif s == "Th" then
		return 3
	elseif s == "Fo" then
		return 4
	elseif s == "Fi" then
		return 5
	elseif s == "Si" then
		return 6
	elseif s == "Se" then
		return 7
	elseif s == "Ei" then
		return 8
	elseif s == "Ni" then
		return 9
	else
		return 10
	end
end

function SumHand(hand)
	sum = 0
	aces = 0

	-- Add all non-ace cards and count aces
	for i=1,#hand do
		value = GetCardValue(hand[i])
		-- If the card is an ace, we don't add it just yet.
		if value == 11 then
			aces = aces + 1
		else
			sum = sum + value
		end
	end

	-- Add the aces
	for i=1,aces do
		if i < aces then
			sum = sum + 1
		else
			if sum + 11 <= 21 then
				sum = sum + 11
			else
				sum = sum + 1
			end
		end
	end

	return sum
end

function DrawCard()
	-- Save top card
	local card = deck[topOfDeck]

	-- Increment deck pointer
	topOfDeck = topOfDeck + 1

	-- Wrap the deck pointer
	if topOfDeck > numberOfCards then
		topOfDeck = 1
	end

	return card
end

function PrintHands()
	-- Show dealer top card
	term.clear()
	term.setCursorPos(1,1)
	term.setBackgroundColor(colors.white)
	term.setTextColor(colors.black)
	print("Dealer top card: ")
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	print(" " .. dealerHand[1])

	-- Show player hand
	term.setCursorPos(1, 6)
	term.setBackgroundColor(colors.white)
	term.setTextColor(colors.black)
	print("Player hand: ")
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	PrintHand(playerHand)
end

function PrintHandValue(_string, _value)
	term.write(_string)

	if _value == 21 then
		term.setTextColor(colors.lime)
	elseif _value > 21 then
		term.setTextColor(colors.red)
	elseif _value == 20 then
		term.setTextColor(colors.orange)
	elseif _value == 18 or _value == 19 then
		term.setTextColor(colors.yellow)
	else
		term.setTextColor(colors.lightGray)
	end

	print(_value)

	term.setTextColor(colors.white)
end

function PlayHand()
	playerHand = {}
	dealerHand = {}
	local done = 0

	-- Draw Hands
	table.insert(playerHand, DrawCard())
	table.insert(dealerHand, DrawCard())
	table.insert(playerHand, DrawCard())
	table.insert(dealerHand, DrawCard())

	while done == 0 do
		PrintHands()

		-- Get Action
		term.setCursorPos(1, height - 2)
		PrintHandValue("You have ", SumHand(playerHand))
		print("Do you 'hit', 'stay', or do you want 'help'?")
		term.write(PROMPT_PREFIX .. "/hand> ")
		local input = readOrTimeout()
		if input == "hit" or input == "h" then
			table.insert(playerHand, DrawCard())

			-- Check for bust
			if SumHand(playerHand) > 21 then
				done = 1
			end
		elseif input == "stay" or input == "s" then
			done = 1
		elseif input == nil or input == 'new' or input == 'n' then
			return -1
		elseif ARCADE_MODE == 0 and (input == 'quit' or input == 'q') then
			return -2
		elseif input == 'help' then
			print("Commands:")
			print("hit or h - Requests a new card from the dealer.")
			print("stay or s - Let the dealer play his hand to see if you win.")
			print("new or n - Starts a new game.")
			if ARCADE_MODE == 0 then
				print("quit or q - Quits Blackjack.")
			end
			print("help - Shows this message.")
			if not PressAnyKey() then
				return -1
			end
		end
	end

	-- Dealer logic
	local done = 0
	-- Don't do anything if the player busted.
	if SumHand(playerHand) > 21 then
		done = 1
	end
	while done == 0 do
		local sum = SumHand(dealerHand)
		if sum < 17 then
			table.insert(dealerHand, DrawCard())
		else
			done = 1
		end
	end

	-- Game result logic
	local win = 0
	local playerSum = SumHand(playerHand)
	if playerSum > 21 then
		win = 0
	else
		local dealerSum = SumHand(dealerHand)
		if dealerSum > 21 then
			win = 1
		elseif playerSum > dealerSum then
			win = 1
		end
	end

	-- Notify player of result
	term.clear()
	term.setCursorPos(1,1)
	term.setBackgroundColor(colors.white)
	term.setTextColor(colors.black)
	print("\nDealer hand: ")
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	PrintHand(dealerHand)
	term.setBackgroundColor(colors.white)
	term.setTextColor(colors.black)
	print("\nPlayer hand: ")
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	PrintHand(playerHand)
	term.setCursorPos(1, height - 3)
	PrintHandValue("Dealer has ", SumHand(dealerHand))
	PrintHandValue("You have ",SumHand(playerHand))
	if win == 1 then
		term.setTextColor(colors.lime)
		print("You won!")
	else
		term.setTextColor(colors.red)
		print("You lost.")
	end
	term.setTextColor(colors.white)
	if not PressAnyKey() then
   return -1
  end

	return win
end

function GetBet()
	-- Calculate max bet
	local max_bet = math.floor(money * MAX_BET_PERCENT / 100)
	if max_bet < MAX_BET_FLAT then
		max_bet = MAX_BET_FLAT
	end

	-- If max bet is higher than player's money when their total money is max bet.
	if max_bet > money then
		max_bet = money
	end

	local done = 0
	while 1==1 do
		term.clear()
		term.setCursorPos(1,1)
		print("Player money: " .. money)
		print("Max bet: " .. max_bet)
		print("Place your bet, or type 'help' for a list of commands.")
		term.write(PROMPT_PREFIX .. "/bet> ")
		local input = readOrTimeout()

		if input == nil or input == 'new' or input == 'n' then
			return -1
		elseif ARCADE_MODE == 0 and (input == 'quit' or input == 'q') then
			return -2
		elseif input == 'help' then
			print("Commands:")
			print("<number> - Bets a dollar amount.")
			print("new or n - Starts a new game.")
			if ARCADE_MODE == 0 then
				print("quit or q - Quits Blackjack.")
			end
			print("help - Shows this message.")
			if not PressAnyKey() then
				return -1
			end
		else
			input = tonumber(input)

			if input == nil or input <= 0 then
				print("You must place a bet or use a valid command!")
				if not PressAnyKey() then
					return -1
				end
			elseif input > max_bet then
				print("Max bet is " .. max_bet .. "!")
				if not PressAnyKey() then
				  return -1
				end
			elseif input > money then
				print("You do not have the money to bet that high!")
				if not PressAnyKey() then
					return -1
				end
			else
				return input
			end
		end
	end
end

function GetName()
	local done = 0
	local name = nil

	while done == 0 do
		term.clear()
		term.setCursorPos(1, 1)
		print("What is your name?")
		term.write(PROMPT_PREFIX .. "/name> ")
		name = readOrTimeout()

		if name == nil then
			return nil
		end

		-- Check the length of the string
		if string.len(name) <= PLAYER_NAME_MAX_LENGTH then
			-- Check for non-alphanumeric
			if string.len(name) > 0 and string.match(name, "%W") == nil then
				done = 1
			else
				print("Sorry, you must use letters and numbers.")
				if not PressAnyKey() then
				  return -1
				end
			end
		else
			print("That name is too long! Max length is " .. PLAYER_NAME_MAX_LENGTH .. " characters.")
			if not PressAnyKey() then
			  return -1
			end
		end
	end

	return name
end

function PlayGame()
	-- Get the player's name
	name = GetName()
	if name == nil then
		return -1
	end

	-- Init game variables
	money = START_MONEY
	topOfDeck = 1
	GetHighScore()

	-- Shuffle deck
	for i=1,#deck do
		j = math.random(1, numberOfCards)
		temp = deck[i]
		deck[i] = deck[j]
		deck[j] = temp
	end

	while 1==1 do
		local bet = GetBet()
		-- Check if we need to quit
		if bet < 0 then
			return bet
		end

		local win = PlayHand()
		-- Check if we need to quit
		if win < 0 then
			return win
		end

		-- Give or take money depending on game result
		if win == 1 then
			money = money + bet
		else
			money = money - bet
			if money <= 0 then
				local image = nil

				if fs.exists(DIRECTORY .. "/" .. GAMEOVER_ARTWORK) then
					image = paintutils.loadImage(DIRECTORY .. "/" .. GAMEOVER_ARTWORK)
					paintutils.drawImage(image, 1, 1)
					term.setCursorPos(12, height - 1)
					term.setTextColor(colors.black)
				else
					term.clear()
					term.setCursorPos(1, 1)
					print("Game Over! Nerd.")
				end
				os.sleep(3)
				PressAnyKey()
				return -1
			end
		end

		-- Check high score and then notify player.
		GetHighScore()
		if money > highscore then
			term.clear()
			term.setCursorPos(1, 1)
			print("You have just set the high score.")
			print("Previous high score was $" .. highscore .. " by " .. highscore_name)
			print("You beat it with your $" .. money)
			print("You beat it by $" .. money - highscore)
			SetHighScore(money, name)
			if not PressAnyKey() then
				return -1
			end
		end
	end
end

-- Find monitor
function FindMonitor(_type)
	local priority_position
	local constant_string

	if _type == "highscore" then
		priority_position = HIGHSCORE_MONITOR_PRIORITY_POSITION
		constant_string = "HIGHSCORE_MONITOR"
	else -- if _type == "artwork" then
		priority_position = ARTWORK_MONITOR_PRIORITY_POSITION
		constant_string = "ARTWORK_MONITOR"
	end

	-- Check preferred direction First
	if peripheral.isPresent(priority_position) == true and peripheral.getType(priority_position) == "monitor" then
			return peripheral.wrap(priority_position)
	end

	-- Check in all possible positions
	for i=1,#positions do
		if peripheral.isPresent(positions[i]) == true and peripheral.getType(positions[i]) == "monitor" then
			return peripheral.wrap(positions[i])
		end
	end

	-- Output message to let user know that we didn't find a monitor
	term.clear()
	term.setCursorPos(1, 1)
	print("An external monitor was not found!")
	print("The highscore will not be displayed on a monitor.")
	print("Set " .. constant_string .. " to 0 to suppress this message.")
	PressAnyKey()

	return nil
end

-- Check for a high score monitor
if highscore_monitor_enabled == 1 then
	highscore_monitor = FindMonitor("highscore")
	if not highscore_monitor then
		highscore_monitor_enabled = 0
	end
end

-- Check for artwork and an artwork monitor
if artwork_monitor_enabled == 1 then
	if fs.exists(DIRECTORY .. "/" .. MONITOR_ARTWORK) then
		artwork_monitor = FindMonitor("artwork")
		if not artwork_monitor then
			artwork_monitor_enabled = 0
		end
		artwork_monitor_image = paintutils.loadImage(DIRECTORY .. "/" .. MONITOR_ARTWORK)
	else
		artwork_monitor_enabled = 0
	end
end

-- Check for directory
if not fs.isDir(DIRECTORY) then
	fs.makeDir(DIRECTORY)
end

-- Go ahead and fetch the high score and draw on the monitor
GetHighScore()

-- Main loop
quit = 0
while quit == 0 do
	local image = nil

	if fs.exists(DIRECTORY .. "/" .. MAIN_MENU_ARTWORK) then
		image = paintutils.loadImage(DIRECTORY .. "/" .. MAIN_MENU_ARTWORK)
		paintutils.drawImage(image, 1, 1)
	else
		term.setBackgroundColor(colors.lime)
		term.clear()
	end

	if artwork_monitor_enabled == 1 then
		artwork_monitor.setTextScale(0.5)
		local terminal = term.current()
		term.redirect(artwork_monitor)
		paintutils.drawImage(artwork_monitor_image, 1, 1)
		term.redirect(terminal)
	end

	term.setCursorPos(30, 8)
	term.setBackgroundColor(colors.green)
	term.setTextColor(colors.black)
	print("Blackjack")
	term.setCursorPos(31, 12)
	term.setBackgroundColor(colors.lime)
	print("A game by d4")
	term.setCursorPos(12, height)
	print("<Press any key to continue>")
	os.pullEvent("key")
	os.sleep(PRESS_ANY_KEY_DELAY)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	local game_result = PlayGame()
	if game_result == -2 then
		quit = 1
	end
end
