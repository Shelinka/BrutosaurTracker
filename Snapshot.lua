local ADDON_NAME, BT = ...

function BT:TakeDailySnapshot()
    local dayKey = self:DayKey()
    self.db.snapshots[dayKey] = self:GetTotalGold()
end


function BT:GetSnapshotSeries(days)
    days = days or self.db.settings.graphRangeDays or 365
    local series = {}
    local carry = nil

    local todayKey = tonumber(self:DayKey())

    for i = days - 1, 0, -1 do
        local t = time() - i * 86400
        local key = self:DayKey(t)
        local value = self.db.snapshots[key]
        if value ~= nil then
            carry = value
        end
        table.insert(series, { t = self:DayKeyToDate(key), gold = carry or 0, key = key, hasData = value ~= nil })
    end

    return series
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
