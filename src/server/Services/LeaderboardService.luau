--!nonstrict
-- Ranking del servidor en el panel de la plaza + leaderstats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.TinyEmpireShared.Format)
local Economy = require(ReplicatedStorage.TinyEmpireShared.Economy)

local LeaderboardService = {}

function LeaderboardService.setup(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "💰 Dinero"
	cash.Value = "$0"
	cash.Parent = ls
	local level = Instance.new("IntValue")
	level.Name = "⭐ Nivel"
	level.Value = 1
	level.Parent = ls
	ls.Parent = player
end

function LeaderboardService.update(player, data)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	local cash = ls:FindFirstChild("💰 Dinero")
	if cash then
		cash.Value = Format.cash(data.cash)
	end
	local level = ls:FindFirstChild("⭐ Nivel")
	if level then
		level.Value = Economy.empireLevel(data.runEarned)
	end
end

function LeaderboardService.start(map, getStates)
	local board = map:FindFirstChild("LeaderboardBoard", true)
	local label = nil
	if board then
		local gui = board:FindFirstChildOfClass("SurfaceGui")
		local frame = gui and gui:FindFirstChildOfClass("Frame")
		if frame then
			for _, c in ipairs(frame:GetChildren()) do
				if c:IsA("TextLabel") and c.TextXAlignment == Enum.TextXAlignment.Left then
					label = c
				end
			end
		end
	end
	task.spawn(function()
		while true do
			local rows = {}
			for player, state in pairs(getStates()) do
				if state.ready and player.Parent then
					table.insert(rows, { name = player.DisplayName, earned = state.data.lifetimeEarned, income = Economy.totalIncome(state.data, state.passes.x2) })
				end
			end
			table.sort(rows, function(a, b)
				return a.earned > b.earned
			end)
			local lines = {}
			local medals = { "🥇", "🥈", "🥉" }
			for i = 1, math.min(8, #rows) do
				local r = rows[i]
				table.insert(lines, string.format("%s %s  %s  (%s/s)", medals[i] or (i .. "."), r.name, Format.cash(r.earned), Format.cash(r.income)))
			end
			if #lines == 0 then
				lines = { "¡Sé el primero en el ranking!" }
			end
			if label then
				label.Text = table.concat(lines, "\n")
			end
			task.wait(8)
		end
	end)
	local _ = Players
end

return LeaderboardService
