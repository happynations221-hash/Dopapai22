--[[
    Sistema de Alocação de Bases para Roblox
    ========================================
    
    INSTRUÇÕES DE INSTALAÇÃO:
    1. Coloque este script no ServerScriptService
    2. Certifique-se de que no Workspace existe:
       - Uma pasta chamada "Bases"
       - Dentro de "Bases", um modelo chamado "BaseTemplate"
       - Modelos de posição: CasaOri1, CasaOri2, CasaOri3, etc.
    3. No mapa, coloque SpawnPoint (Parts) com atributo HouseName
       - O valor deve corresponder ao nome de uma CasaOri (ex: CasaOri3)
    
    REQUISITOS DO MODELO BaseTemplate:
    - Deve ter um PrimaryPart definido para posicionamento correto
    - Se não tiver PrimaryPart, o script irá usar o primeiro Part encontrado
    
    FUNCIONALIDADES:
    - Alocação automática de bases ao entrar no jogo
    - Sistema de propriedade com StringValue "Owner"
    - Teleporte automático para a base
    - Comando /home para retornar à base
    - Liberação automática ao sair do jogo
    - Proteção contra erros e duplicações
    - Logs detalhados no Output
]]

-- Serviços necessários
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Configurações do sistema
local CONFIG = {
    TELEPORT_MODE = "SMOOTH", -- "INSTANT" ou "SMOOTH"
    TELEPORT_DURATION = 1.5, -- Duração do teleporte suave em segundos
    CLEANUP_TIMEOUT = 300, -- Timeout para limpeza de bases órfãs (5 minutos)
    COMMAND_PREFIX = "/home" -- Comando para retornar à base
}

-- Tabelas para controle interno
local baseOwners = {} -- [baseName] = playerName
local playerBases = {} -- [playerName] = baseName
local availableBases = {} -- Lista de bases disponíveis
local baseModels = {} -- [baseName] = baseModel

-- Função para logar mensagens no Output
local function log(message, messageType)
    messageType = messageType or "INFO"
    print("[SISTEMA DE BASES] " .. messageType .. ": " .. message)
end

-- Função para verificar se uma base está disponível
local function isBaseAvailable(baseName)
    return availableBases[baseName] == true
end

-- Função para marcar base como ocupada
local function markBaseAsOccupied(baseName, playerName)
    baseOwners[baseName] = playerName
    playerBases[playerName] = baseName
    availableBases[baseName] = false
    log("Base '" .. baseName .. "' alocada para '" .. playerName .. "'")
end

-- Função para marcar base como disponível
local function markBaseAsAvailable(baseName)
    local previousOwner = baseOwners[baseName]
    if previousOwner then
        baseOwners[baseName] = nil
        playerBases[previousOwner] = nil
        log("Base '" .. baseName .. "' liberada de '" .. previousOwner .. "'")
    end
    availableBases[baseName] = true
end

-- Função para encontrar uma base disponível
local function findAvailableBase()
    for baseName, isAvailable in pairs(availableBases) do
        if isAvailable then
            return baseName
        end
    end
    return nil
end

-- Função para teleportar jogador para sua base
local function teleportPlayerToBase(player, baseName)
    local baseModel = baseModels[baseName]
    if not baseModel then
        log("Erro: Base '" .. baseName .. "' não encontrada", "ERROR")
        return false
    end
    
    local character = player.Character
    if not character then
        log("Erro: Character de '" .. player.Name .. "' não encontrado", "ERROR")
        return false
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        log("Erro: HumanoidRootPart de '" .. player.Name .. "' não encontrado", "ERROR")
        return false
    end
    
    -- Determinar posição de teleporte (dentro da base)
    local teleportPosition
    if baseModel.PrimaryPart then
        teleportPosition = baseModel.PrimaryPart.CFrame + Vector3.new(0, 5, 0) -- 5 studs acima
    else
        -- Fallback: usar primeiro Part encontrado
        local firstPart = baseModel:FindFirstChildOfClass("BasePart")
        if firstPart then
            teleportPosition = firstPart.CFrame + Vector3.new(0, 5, 0)
        else
            log("Erro: Nenhuma Part encontrada na base '" .. baseName .. "'", "ERROR")
            return false
        end
    end
    
    -- Executar teleporte baseado na configuração
    if CONFIG.TELEPORT_MODE == "INSTANT" then
        humanoidRootPart.CFrame = teleportPosition
        log("Jogador '" .. player.Name .. "' teleportado instantaneamente para base '" .. baseName .. "'")
    else
        -- Teleporte suave com tween
        local tweenInfo = TweenInfo.new(
            CONFIG.TELEPORT_DURATION,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )
        local tween = TweenService:Create(humanoidRootPart, tweenInfo, {
            CFrame = teleportPosition
        })
        tween:Play()
        log("Jogador '" .. player.Name .. "' sendo teleportado suavemente para base '" .. baseName .. "'")
    end
    
    return true
end

-- Função para criar e alocar uma base para um jogador
local function allocateBaseForPlayer(player)
    -- Verificar se o jogador já tem uma base
    if playerBases[player.Name] then
        log("Jogador '" .. player.Name .. "' já possui base '" .. playerBases[player.Name] .. "'")
        return false
    end
    
    -- Encontrar uma base disponível
    local availableBaseName = findAvailableBase()
    if not availableBaseName then
        log("Nenhuma base disponível para '" .. player.Name .. "'", "WARN")
        return false
    end
    
    -- Encontrar o SpawnPoint correspondente
    local spawnPoint = nil
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "SpawnPoint" then
            local houseName = obj:GetAttribute("HouseName")
            if houseName == availableBaseName then
                spawnPoint = obj
                break
            end
        end
    end
    
    if not spawnPoint then
        log("Erro: SpawnPoint para base '" .. availableBaseName .. "' não encontrado", "ERROR")
        return false
    end
    
    -- Clonar a base template
    local baseTemplate = Workspace.Bases:FindFirstChild("BaseTemplate")
    if not baseTemplate then
        log("Erro: BaseTemplate não encontrado em Workspace.Bases", "ERROR")
        return false
    end
    
    local newBase = baseTemplate:Clone()
    newBase.Name = availableBaseName .. "_" .. player.Name
    
    -- Posicionar a base no SpawnPoint
    if newBase.PrimaryPart then
        newBase:SetPrimaryPartCFrame(spawnPoint.CFrame)
    else
        -- Fallback: usar PivotTo se não houver PrimaryPart
        newBase:PivotTo(spawnPoint.CFrame)
        log("Aviso: Base '" .. newBase.Name .. "' não tem PrimaryPart, usando PivotTo", "WARN")
    end
    
    -- Adicionar a base ao Workspace
    newBase.Parent = Workspace
    
    -- Criar StringValue para marcar o dono
    local ownerValue = Instance.new("StringValue")
    ownerValue.Name = "Owner"
    ownerValue.Value = player.Name
    ownerValue.Parent = newBase
    
    -- Marcar base como ocupada
    markBaseAsOccupied(availableBaseName, player.Name)
    baseModels[availableBaseName] = newBase
    
    log("Base '" .. availableBaseName .. "' criada e alocada para '" .. player.Name .. "'")
    return true
end

-- Função para liberar base de um jogador
local function releasePlayerBase(player)
    local baseName = playerBases[player.Name]
    if not baseName then
        log("Jogador '" .. player.Name .. "' não possui base para liberar")
        return
    end
    
    local baseModel = baseModels[baseName]
    if baseModel then
        -- Remover a base do Workspace
        baseModel:Destroy()
        baseModels[baseName] = nil
        log("Base '" .. baseName .. "' removida do Workspace")
    end
    
    -- Marcar como disponível
    markBaseAsAvailable(baseName)
end

-- Função para processar comando de chat
local function processChatCommand(player, message)
    if message:lower() == CONFIG.COMMAND_PREFIX:lower() then
        local baseName = playerBases[player.Name]
        if baseName then
            if teleportPlayerToBase(player, baseName) then
                log("Comando /home executado para '" .. player.Name .. "'")
            end
        else
            log("Jogador '" .. player.Name .. "' não possui base para retornar", "WARN")
        end
    end
end

-- Função para inicializar o sistema
local function initializeSystem()
    log("Iniciando Sistema de Alocação de Bases...")
    
    -- Aguardar pela pasta Bases
    local basesFolder = Workspace:WaitForChild("Bases", 10)
    if not basesFolder then
        log("ERRO CRÍTICO: Pasta 'Bases' não encontrada no Workspace!", "ERROR")
        return false
    end
    
    -- Aguardar pelo BaseTemplate
    local baseTemplate = basesFolder:WaitForChild("BaseTemplate", 10)
    if not baseTemplate then
        log("ERRO CRÍTICO: 'BaseTemplate' não encontrado em Bases!", "ERROR")
        return false
    end
    
    -- Verificar se BaseTemplate tem PrimaryPart
    if not baseTemplate.PrimaryPart then
        log("AVISO: BaseTemplate não tem PrimaryPart definido. O sistema funcionará, mas pode haver problemas de posicionamento.", "WARN")
    end
    
    -- Encontrar todas as posições de base disponíveis
    local baseCount = 0
    for _, obj in pairs(basesFolder:GetChildren()) do
        if obj.Name:match("^CasaOri%d+$") then -- Padrão CasaOri + número
            availableBases[obj.Name] = true
            baseCount = baseCount + 1
            log("Base disponível encontrada: " .. obj.Name)
        end
    end
    
    if baseCount == 0 then
        log("ERRO CRÍTICO: Nenhuma posição de base (CasaOri) encontrada!", "ERROR")
        return false
    end
    
    log("Sistema inicializado com " .. baseCount .. " bases disponíveis")
    return true
end

-- Função para limpeza de bases órfãs
local function cleanupOrphanedBases()
    log("Executando limpeza de bases órfãs...")
    
    for baseName, baseModel in pairs(baseModels) do
        local owner = baseOwners[baseName]
        if owner then
            local player = Players:FindFirstChild(owner)
            if not player then
                -- Jogador não está mais online, liberar base
                log("Liberando base órfã '" .. baseName .. "' do jogador offline '" .. owner .. "'")
                releasePlayerBase(Players:FindFirstChild(owner) or {Name = owner})
            end
        end
    end
end

-- Eventos principais
local function onPlayerAdded(player)
    log("Jogador '" .. player.Name .. "' entrou no jogo")
    
    -- Aguardar o Character carregar
    local character = player.Character or player.CharacterAdded:Wait()
    
    -- Alocar base para o jogador
    if allocateBaseForPlayer(player) then
        -- Teleportar para a base após um pequeno delay
        wait(1)
        local baseName = playerBases[player.Name]
        if baseName then
            teleportPlayerToBase(player, baseName)
        end
    end
    
    -- Conectar evento de Character respawn
    player.CharacterAdded:Connect(function(newCharacter)
        wait(1) -- Aguardar carregamento completo
        local baseName = playerBases[player.Name]
        if baseName then
            teleportPlayerToBase(player, baseName)
        end
    end)
    
    -- Conectar evento de chat
    player.Chatted:Connect(function(message)
        processChatCommand(player, message)
    end)
end

local function onPlayerRemoving(player)
    log("Jogador '" .. player.Name .. "' saindo do jogo")
    releasePlayerBase(player)
end

-- Inicialização do sistema
if initializeSystem() then
    -- Conectar eventos
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    
    -- Configurar limpeza periódica de bases órfãs
    spawn(function()
        while wait(CONFIG.CLEANUP_TIMEOUT) do
            cleanupOrphanedBases()
        end
    end)
    
    log("Sistema de Alocação de Bases ativado com sucesso!")
else
    log("ERRO: Falha na inicialização do sistema!", "ERROR")
end

--[[
    INFORMAÇÕES ADICIONAIS:
    
    LIMITAÇÕES CONHECIDAS:
    1. Se BaseTemplate não tiver PrimaryPart, o sistema usará PivotTo como fallback
    2. O sistema assume que SpawnPoints são Parts com atributo HouseName
    3. Bases são destruídas ao sair do jogo (não persistem entre sessões)
    
    COMO AJUSTAR:
    1. Para definir PrimaryPart: Selecione o modelo BaseTemplate, clique com botão direito
       no Part desejado e escolha "Set Primary Part"
    2. Para criar SpawnPoints: Crie Parts no mapa, adicione atributo "HouseName" 
       com valor igual ao nome de uma CasaOri
    3. Para mudar nomes: Edite as variáveis no início do script
    
    COMANDOS DISPONÍVEIS:
    - /home: Teleporta o jogador de volta para sua base
    
    LOGS NO OUTPUT:
    - Todas as operações são logadas com prefixo [SISTEMA DE BASES]
    - Use o Output do Roblox Studio para monitorar o funcionamento
    
    CONFIGURAÇÕES:
    - TELEPORT_MODE: "INSTANT" para teleporte imediato, "SMOOTH" para animação
    - TELEPORT_DURATION: Duração do teleporte suave em segundos
    - CLEANUP_TIMEOUT: Intervalo para limpeza de bases órfãs
]]