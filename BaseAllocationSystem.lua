--[[
    SISTEMA DE ALOCAÇÃO DE BASES PARA ROBLOX
    
    Como usar:
    1. Coloque este script no ServerScriptService
    2. Certifique-se de que existe uma pasta "Bases" no Workspace
    3. Dentro de Bases deve haver:
       - Um modelo "BaseTemplate" (que será clonado)
       - Modelos de posição "CasaOri1", "CasaOri2", etc.
    4. No mapa deve haver Parts chamadas "SpawnPoint" com atributo "HouseName"
    
    Funcionalidades:
    - Alocação automática de bases ao entrar
    - Liberação automática ao sair
    - Teleporte para a base (instantâneo ou suave)
    - Comando /home no chat
    - Proteção contra erros
    - Sistema de limpeza de bases órfãs
--]]

-- Serviços necessários
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Configurações do sistema
local CONFIG = {
    SMOOTH_TELEPORT = true,  -- true para teleporte suave, false para instantâneo
    TWEEN_TIME = 1.5,        -- Tempo do teleporte suave em segundos
    CLEANUP_INTERVAL = 300,  -- Intervalo de limpeza em segundos (5 minutos)
    DEBUG_LOGS = true        -- Mostrar logs detalhados no Output
}

-- Tabelas de controle interno
local baseOwners = {}     -- [baseName] = playerName
local playerBases = {}    -- [playerName] = baseName
local spawnPoints = {}    -- [houseName] = SpawnPoint part
local occupiedBases = {}  -- [baseName] = true/false

-- Referências principais
local basesFolder
local baseTemplate

-- Função para logs com timestamp
local function logMessage(message, logType)
    logType = logType or "INFO"
    local timestamp = os.date("[%H:%M:%S]")
    local fullMessage = timestamp .. " [BASE_SYSTEM] [" .. logType .. "] " .. message
    
    if logType == "ERROR" then
        error(fullMessage)
    elseif logType == "WARN" then
        warn(fullMessage)
    else
        print(fullMessage)
    end
end

-- Função para inicializar o sistema
local function initializeSystem()
    logMessage("Inicializando sistema de alocação de bases...")
    
    -- Aguardar e verificar a pasta Bases
    local success, result = pcall(function()
        basesFolder = Workspace:WaitForChild("Bases", 10)
    end)
    
    if not success or not basesFolder then
        logMessage("ERRO: Pasta 'Bases' não encontrada no Workspace!", "ERROR")
        return false
    end
    
    -- Aguardar e verificar o BaseTemplate
    success, result = pcall(function()
        baseTemplate = basesFolder:WaitForChild("BaseTemplate", 10)
    end)
    
    if not success or not baseTemplate then
        logMessage("ERRO: Modelo 'BaseTemplate' não encontrado na pasta Bases!", "ERROR")
        return false
    end
    
    -- Verificar se BaseTemplate tem PrimaryPart
    if not baseTemplate.PrimaryPart then
        logMessage("AVISO: BaseTemplate não possui PrimaryPart definido. Tentando usar a primeira Part encontrada...", "WARN")
        for _, child in pairs(baseTemplate:GetChildren()) do
            if child:IsA("BasePart") then
                baseTemplate.PrimaryPart = child
                break
            end
        end
        
        if not baseTemplate.PrimaryPart then
            logMessage("ERRO: BaseTemplate não possui nenhuma Part válida para usar como PrimaryPart!", "ERROR")
            return false
        end
    end
    
    -- Mapear todos os SpawnPoints
    local function mapSpawnPoints()
        spawnPoints = {}
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == "SpawnPoint" and obj:IsA("BasePart") then
                local houseName = obj:GetAttribute("HouseName")
                if houseName then
                    spawnPoints[houseName] = obj
                    logMessage("SpawnPoint mapeado: " .. houseName)
                else
                    logMessage("SpawnPoint encontrado sem atributo HouseName: " .. obj:GetFullName(), "WARN")
                end
            end
        end
        logMessage("Total de SpawnPoints mapeados: " .. #spawnPoints)
    end
    
    mapSpawnPoints()
    
    -- Verificar se existem CasaOri e SpawnPoints correspondentes
    local availableBases = 0
    for _, child in pairs(basesFolder:GetChildren()) do
        if child.Name:match("^CasaOri%d+$") then
            if spawnPoints[child.Name] then
                occupiedBases[child.Name] = false
                availableBases = availableBases + 1
                logMessage("Base disponível encontrada: " .. child.Name)
            else
                logMessage("Base " .. child.Name .. " não possui SpawnPoint correspondente!", "WARN")
            end
        end
    end
    
    if availableBases == 0 then
        logMessage("ERRO: Nenhuma base válida encontrada! Verifique se existem CasaOri e SpawnPoints correspondentes.", "ERROR")
        return false
    end
    
    logMessage("Sistema inicializado com sucesso! Bases disponíveis: " .. availableBases)
    return true
end

-- Função para encontrar uma base livre
local function findFreeBase()
    for baseName, isOccupied in pairs(occupiedBases) do
        if not isOccupied then
            return baseName
        end
    end
    return nil
end

-- Função para teleportar jogador
local function teleportPlayer(player, position, rotation)
    local character = player.Character
    if not character then
        logMessage("Personagem do jogador " .. player.Name .. " não encontrado para teleporte", "WARN")
        return
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        logMessage("HumanoidRootPart não encontrado para " .. player.Name, "WARN")
        return
    end
    
    -- Ajustar posição para evitar spawn no chão
    local teleportPosition = position + Vector3.new(0, 5, 0)
    local teleportCFrame = CFrame.new(teleportPosition, teleportPosition + (rotation.LookVector * Vector3.new(1, 0, 1)).Unit)
    
    if CONFIG.SMOOTH_TELEPORT then
        -- Teleporte suave com tween
        local tweenInfo = TweenInfo.new(
            CONFIG.TWEEN_TIME,
            Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out
        )
        
        local tween = TweenService:Create(humanoidRootPart, tweenInfo, {CFrame = teleportCFrame})
        tween:Play()
        
        logMessage("Teleportando " .. player.Name .. " suavemente para sua base")
    else
        -- Teleporte instantâneo
        humanoidRootPart.CFrame = teleportCFrame
        logMessage("Teleportando " .. player.Name .. " instantaneamente para sua base")
    end
end

-- Função para alocar base para jogador
local function allocateBase(player)
    -- Verificar se jogador já possui base
    if playerBases[player.Name] then
        logMessage("Jogador " .. player.Name .. " já possui uma base: " .. playerBases[player.Name])
        return
    end
    
    -- Encontrar base livre
    local freeBaseName = findFreeBase()
    if not freeBaseName then
        logMessage("Nenhuma base livre disponível para " .. player.Name, "WARN")
        return
    end
    
    -- Obter SpawnPoint correspondente
    local spawnPoint = spawnPoints[freeBaseName]
    if not spawnPoint then
        logMessage("SpawnPoint não encontrado para base " .. freeBaseName, "ERROR")
        return
    end
    
    -- Clonar BaseTemplate
    local newBase = baseTemplate:Clone()
    newBase.Name = freeBaseName .. "_" .. player.Name
    
    -- Criar/atualizar StringValue Owner
    local ownerValue = newBase:FindFirstChild("Owner")
    if not ownerValue then
        ownerValue = Instance.new("StringValue")
        ownerValue.Name = "Owner"
        ownerValue.Parent = newBase
    end
    ownerValue.Value = player.Name
    
    -- Posicionar a base no SpawnPoint
    if newBase.PrimaryPart then
        newBase:SetPrimaryPartCFrame(spawnPoint.CFrame)
    else
        logMessage("ERRO: Base clonada não possui PrimaryPart!", "ERROR")
        newBase:Destroy()
        return
    end
    
    -- Colocar a base no workspace
    newBase.Parent = Workspace
    
    -- Atualizar tabelas de controle
    baseOwners[freeBaseName] = player.Name
    playerBases[player.Name] = freeBaseName
    occupiedBases[freeBaseName] = true
    
    logMessage("Base " .. freeBaseName .. " alocada para " .. player.Name .. " com sucesso!")
    
    -- Aguardar character carregar e teleportar
    local function onCharacterAdded(character)
        wait(1) -- Pequena espera para garantir que tudo carregou
        teleportPlayer(player, spawnPoint.Position, spawnPoint.CFrame)
    end
    
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    player.CharacterAdded:Connect(onCharacterAdded)
end

-- Função para liberar base do jogador
local function releaseBase(player)
    local baseName = playerBases[player.Name]
    if not baseName then
        logMessage("Jogador " .. player.Name .. " não possui base para liberar")
        return
    end
    
    -- Encontrar e remover a base do workspace
    local baseModel = Workspace:FindFirstChild(baseName .. "_" .. player.Name)
    if baseModel then
        baseModel:Destroy()
        logMessage("Base física removida: " .. baseModel.Name)
    end
    
    -- Limpar tabelas de controle
    baseOwners[baseName] = nil
    playerBases[player.Name] = nil
    occupiedBases[baseName] = false
    
    logMessage("Base " .. baseName .. " liberada do jogador " .. player.Name)
end

-- Função para comando /home
local function onPlayerChatted(player, message)
    if message:lower() == "/home" then
        local baseName = playerBases[player.Name]
        if not baseName then
            logMessage("Jogador " .. player.Name .. " tentou usar /home mas não possui base")
            return
        end
        
        local spawnPoint = spawnPoints[baseName]
        if spawnPoint then
            teleportPlayer(player, spawnPoint.Position, spawnPoint.CFrame)
            logMessage("Jogador " .. player.Name .. " usou comando /home")
        else
            logMessage("SpawnPoint não encontrado para base " .. baseName .. " do jogador " .. player.Name, "ERROR")
        end
    end
end

-- Função de limpeza de bases órfãs
local function cleanupOrphanBases()
    logMessage("Executando limpeza de bases órfãs...")
    
    local cleanedCount = 0
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name:match("^CasaOri%d+_") then
            local ownerValue = obj:FindFirstChild("Owner")
            if ownerValue and ownerValue.Value then
                local ownerName = ownerValue.Value
                local player = Players:FindFirstChild(ownerName)
                
                -- Se o jogador não está mais no servidor, limpar a base
                if not player then
                    local baseName = obj.Name:match("^(CasaOri%d+)_")
                    if baseName then
                        obj:Destroy()
                        baseOwners[baseName] = nil
                        occupiedBases[baseName] = false
                        cleanedCount = cleanedCount + 1
                        logMessage("Base órfã removida: " .. obj.Name)
                    end
                end
            end
        end
    end
    
    if cleanedCount > 0 then
        logMessage("Limpeza concluída. Bases órfãs removidas: " .. cleanedCount)
    end
end

-- Eventos principais
local function onPlayerAdded(player)
    logMessage("Jogador conectado: " .. player.Name)
    
    -- Conectar evento de chat
    player.Chatted:Connect(function(message)
        onPlayerChatted(player, message)
    end)
    
    -- Alocar base
    allocateBase(player)
end

local function onPlayerRemoving(player)
    logMessage("Jogador desconectando: " .. player.Name)
    releaseBase(player)
end

-- Inicialização do sistema
if initializeSystem() then
    -- Conectar eventos
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    
    -- Processar jogadores já conectados
    for _, player in pairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    
    -- Sistema de limpeza periódica (bônus)
    spawn(function()
        while true do
            wait(CONFIG.CLEANUP_INTERVAL)
            cleanupOrphanBases()
        end
    end)
    
    logMessage("Sistema de alocação de bases totalmente ativo!")
else
    logMessage("Falha na inicialização do sistema de bases!", "ERROR")
end