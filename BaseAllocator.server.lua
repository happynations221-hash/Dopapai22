-- BaseAllocator.server.lua
--[[
    Sistema de alocação de bases para jogadores (ServerScript)
    Coloque este script dentro de ServerScriptService no Roblox Studio.

    Estrutura necessária no Explorer:
    Workspace
        └─ Bases (Folder)
            ├─ BaseTemplate (Model)          -- modelo a ser clonado para cada jogador
            └─ CasaOri1 / CasaOri2 / ...    -- modelos ou Parts que indicam posições das bases (opcional)

    No mapa devem existir SpawnPoints (Part ou SpawnLocation) com o atributo
    "HouseName" cujo valor corresponda exatamente ao nome de uma CasaOri (ex.: "CasaOri3").

    Regras principais:
    • Ao entrar, o jogador recebe a primeira base livre.
    • A base é clonada a partir de BaseTemplate, posicionada no SpawnPoint
      correspondente e marcada com um StringValue "Owner" contendo player.Name.
    • Quando o jogador sair, a base é liberada.
    • Comando de chat "/home" leva o jogador de volta à própria base.

    Ajuste as variáveis de configuração abaixo conforme necessário.
]]

------------------------------
-- Serviços Roblox
------------------------------
local Players       = game:GetService("Players")            -- serviço de jogadores
local TweenService  = game:GetService("TweenService")       -- para teleporte suave
local RunService    = game:GetService("RunService")         -- utilitário (não usado diretamente)
local Workspace     = game:GetService("Workspace")

------------------------------
-- Configurações
------------------------------
local USE_SMOOTH_TELEPORT   = true    -- true = Tween; false = teleporte instantâneo (MoveTo)
local TELEPORT_TIME         = 1       -- duração do tween em segundos
local ORPHAN_CLEANUP_DELAY  = 30      -- tempo após iniciar o servidor para limpar bases órfãs

------------------------------
-- Validações iniciais
------------------------------
-- Aguarda a pasta Bases e o modelo BaseTemplate estarem carregados
local BasesFolder = Workspace:WaitForChild("Bases", 10)
if not BasesFolder then
    error("[BaseAllocator] Pasta 'Bases' não encontrada em Workspace. Crie-a antes de iniciar o jogo.")
end

local BaseTemplate = BasesFolder:WaitForChild("BaseTemplate", 10)
if not BaseTemplate or not BaseTemplate:IsA("Model") then
    error("[BaseAllocator] 'BaseTemplate' não encontrado ou não é um Model dentro de 'Bases'.")
end

------------------------------
-- Mapeamento de SpawnPoints -> CasaOri
------------------------------
local spawnPoints = {}  -- [houseName] = Part/SpawnLocation
for _, descendant in ipairs(Workspace:GetDescendants()) do
    -- Verifica se é Part ou SpawnLocation
    if descendant:IsA("SpawnLocation") or descendant:IsA("Part") then
        local houseName = descendant:GetAttribute("HouseName")
        if typeof(houseName) == "string" and houseName ~= "" then
            spawnPoints[houseName] = descendant
        end
    end
end

if next(spawnPoints) == nil then
    warn("[BaseAllocator] Nenhum SpawnPoint com atributo 'HouseName' encontrado. Jogadores não serão alocados!")
end

------------------------------
-- Estruturas de estado
------------------------------
local baseOwners  = {} -- [houseName] = player (ocupação da base)
local playerBases = {} -- [player] = { houseName = string, model = Model, spawn = Part }

------------------------------
-- Funções auxiliares
------------------------------
-- Atualiza / cria o StringValue "Owner" dentro do modelo
local function setOwnerValue(model: Model, player)
    local ownerVal = model:FindFirstChild("Owner")
    if not ownerVal then
        ownerVal = Instance.new("StringValue")
        ownerVal.Name = "Owner"
        ownerVal.Parent = model
    end
    ownerVal.Value = player and player.Name or ""
end

-- Teleporta o personagem do jogador para um CFrame de destino
local function teleportCharacter(player: Player, targetCF: CFrame)
    if not player.Character or not player.Character.Parent then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if USE_SMOOTH_TELEPORT then
        -- Tween suave do HumanoidRootPart até o destino
        local tween = TweenService:Create(hrp, TweenInfo.new(TELEPORT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCF})
        tween:Play()
        tween.Completed:Wait()
    else
        -- Teleporte instantâneo usando MoveTo (offset em Y para evitar colisões imediatas)
        player.Character:MoveTo(targetCF.Position)
    end
end

-- Procura a primeira base livre e retorna seu nome e SpawnPoint
local function findFreeHouse()
    for houseName, sp in pairs(spawnPoints) do
        if not baseOwners[houseName] then
            return houseName, sp
        end
    end
    return nil, nil
end

-- Aloca base para o jogador (PlayerAdded)
local function allocateBase(player: Player)
    -- Previni alocação duplicada
    if playerBases[player] then
        warn(string.format("[BaseAllocator] Jogador %s já possui base (%s).", player.Name, playerBases[player].houseName))
        return
    end

    local houseName, spawn = findFreeHouse()
    if not houseName then
        warn(string.format("[BaseAllocator] Sem bases livres para o jogador %s.", player.Name))
        return
    end

    -- Clona o modelo da base
    local clone = BaseTemplate:Clone()
    clone.Name = string.format("%s_%s", houseName, player.Name)
    clone.Parent = BasesFolder

    -- Posiciona a base
    if clone.PrimaryPart then
        -- Caso tenha PrimaryPart definido
        clone:SetPrimaryPartCFrame(spawn.CFrame)
    else
        -- Fallback usando PivotTo (Roblox recomenda SetPrimaryPartCFrame quando possível)
        clone:PivotTo(spawn.CFrame)
        warn(string.format("[BaseAllocator] 'BaseTemplate' sem PrimaryPart. Usando PivotTo para posicionar %s.", clone.Name))
    end

    -- Marca o proprietário
    setOwnerValue(clone, player)

    -- Atualiza tabelas de controle
    baseOwners[houseName] = player
    playerBases[player] = {
        houseName = houseName,
        model     = clone,
        spawn     = spawn,
    }

    print(string.format("[BaseAllocator] Base %s alocada para %s.", houseName, player.Name))
end

-- Libera base quando o jogador sai (PlayerRemoving)
local function freeBase(player: Player)
    local info = playerBases[player]
    if not info then return end

    local model     = info.model
    local houseName = info.houseName

    -- Limpa StringValue Owner e destrói o modelo
    if model and model.Parent then
        setOwnerValue(model, nil)
        model:Destroy()
    end

    -- Atualiza tabelas
    baseOwners[houseName] = nil
    playerBases[player]   = nil

    print(string.format("[BaseAllocator] Base %s liberada de %s.", houseName, player.Name))
end

-- Callback CharacterAdded: teleporta personagem para dentro da própria base
local function onCharacterAdded(player: Player, character: Model)
    local info = playerBases[player]
    if not info then return end -- ainda não foi alocada base

    -- Offset vertical para evitar spawn dentro do chão
    local destCF = info.spawn.CFrame + Vector3.new(0, 3, 0)
    teleportCharacter(player, destCF)
end

-- Registra comando de chat /home
local function setupChatCommand(player: Player)
    player.Chatted:Connect(function(message)
        if message:lower() == "/home" then
            local info = playerBases[player]
            if not info then
                warn(string.format("[BaseAllocator] %s utilizou /home mas não possui base.", player.Name))
                return
            end
            local destCF = info.spawn.CFrame + Vector3.new(0, 3, 0)
            teleportCharacter(player, destCF)
        end
    end)
end

------------------------------
-- Limpeza de bases órfãs (bônus)
------------------------------
-- Remove clones que estejam sem Owner (ex.: servidor reiniciado) após ORPHAN_CLEANUP_DELAY segundos.
-- Melhora uso de memória e evita que Bases fiquem "presas".

task.delay(ORPHAN_CLEANUP_DELAY, function()
    for _, model in ipairs(BasesFolder:GetChildren()) do
        -- Ignora o template original
        if model ~= BaseTemplate and model:IsA("Model") then
            local ownerVal = model:FindFirstChild("Owner")
            if not ownerVal or ownerVal.Value == "" then
                model:Destroy()
                print(string.format("[BaseAllocator] Modelo órfão %s removido.", model.Name))
            end
        end
    end
end)

------------------------------
-- Conexões de eventos de jogador
------------------------------
Players.PlayerAdded:Connect(function(player)
    allocateBase(player)                      -- aloca base
    player.CharacterAdded:Connect(function(ch)
        onCharacterAdded(player, ch)          -- teleporta personagem para base
    end)
    setupChatCommand(player)                  -- registra /home
end)

Players.PlayerRemoving:Connect(function(player)
    freeBase(player)                          -- libera base
end)

-- Trata jogadores que já estejam no servidor quando o script iniciar (por hot reload, etc.)
for _, plr in ipairs(Players:GetPlayers()) do
    allocateBase(plr)
    plr.CharacterAdded:Connect(function(ch)
        onCharacterAdded(plr, ch)
    end)
    setupChatCommand(plr)
end

------------------------------
-- Fim do script
------------------------------