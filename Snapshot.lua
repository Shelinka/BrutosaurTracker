local ADDON_NAME, BT = ...

BT.HISTORY_INTERVAL = 2 * 60 * 60

function BT:RecordGoldHistoryPoint()
    local history = self.db.history
    local last = history[#history]
    local now = time()
    if last and (now - last.t) < self.HISTORY_INTERVAL then
        return
    end
    table.insert(history, { t = now, gold = self:GetTotalGold() })
end

function BT:CompactOldGoldHistoryIfNewMonth()
    local currentMonthKey = date("%Y%m")
    if self.db.settings.lastHistoryCompactMonth == currentMonthKey then
        return
    end
    self.db.settings.lastHistoryCompactMonth = currentMonthKey

    local history = self.db.history
    local currentMonthEntries = {}
    local bestPerOldDay = {}

    for _, entry in ipairs(history) do
        if date("%Y%m", entry.t) == currentMonthKey then
            table.insert(currentMonthEntries, entry)
        else
            local dayKey = self:DayKey(entry.t)
            local best = bestPerOldDay[dayKey]
            if not best or entry.gold > best.gold then
                bestPerOldDay[dayKey] = entry
            end
        end
    end

    local oldEntries = {}
    for _, entry in pairs(bestPerOldDay) do
        table.insert(oldEntries, entry)
    end
    table.sort(oldEntries, function(a, b) return a.t < b.t end)

    local compacted = {}
    for _, entry in ipairs(oldEntries) do table.insert(compacted, entry) end
    for _, entry in ipairs(currentMonthEntries) do table.insert(compacted, entry) end

    self.db.history = compacted
end

function BT:GetGoldTimeSeries(days)
    local cutoff = time() - days * 86400
    local points = {}
    for _, entry in ipairs(self.db.history) do
        if entry.t >= cutoff then
            table.insert(points, { x = entry.t, y = entry.gold })
        end
    end
    return points
end

function BT:GetGoldGoal()
    return self.db.settings.goldGoal or 0
end

function BT:SetGoldGoal(amount)
    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end
    self.db.settings.goldGoal = amount
end

function BT:GetGoalProgress()
    local goal = self:GetGoldGoal()
    local current = self:GetTotalGold()
    local remaining = goal - current
    if remaining < 0 then remaining = 0 end
    return goal, current, remaining
end
