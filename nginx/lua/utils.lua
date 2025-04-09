local _M = {}

-- snake_case → camelCase 변환 함수
function _M.snake_to_camel(str)
    return (str:gsub("_([a-z])", function(s)
        return s:upper()
    end))
end

-- row 테이블 통째로 변환
function _M.rows_to_camel(rows)
    local new_rows = {}

    for _, row in ipairs(rows) do
        local new_row = {}

        for k, v in pairs(row) do
            new_row[_M.snake_to_camel(k)] = v
        end

        table.insert(new_rows, new_row)
    end

    return new_rows
end

return _M
