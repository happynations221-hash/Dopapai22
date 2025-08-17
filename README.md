# Sistema de Alocação de Bases para Roblox

Este sistema implementa um sistema completo de alocação automática de bases para jogadores em Roblox, com teleporte, comando de retorno e limpeza automática.

## 📋 Funcionalidades

- ✅ **Alocação automática de bases** ao jogador entrar no servidor
- ✅ **Liberação automática** quando o jogador sai
- ✅ **Teleporte inteligente** (instantâneo ou suave)
- ✅ **Comando /home** para retornar à base
- ✅ **Proteção contra erros** com logs detalhados
- ✅ **Sistema de limpeza** de bases órfãs
- ✅ **Prevenção de duplicações** de bases

## 🚀 Como Instalar

### 1. Preparar o Script
1. Copie todo o conteúdo do arquivo `BaseAllocationSystem.lua`
2. No Roblox Studio, vá para **ServerScriptService**
3. Crie um novo **ServerScript** (não LocalScript!)
4. Cole o código no script
5. Salve o script

### 2. Estrutura Necessária no Workspace

Seu **Workspace** deve ter a seguinte estrutura:

```
Workspace/
├── Bases/
│   ├── BaseTemplate (Model) ← Modelo que será clonado
│   ├── CasaOri1 (Model) ← Posição de referência
│   ├── CasaOri2 (Model) ← Posição de referência
│   └── CasaOri3 (Model) ← Etc...
└── [Outras partes do mapa]/
    ├── SpawnPoint (Part) ← Com atributo HouseName = "CasaOri1"
    ├── SpawnPoint (Part) ← Com atributo HouseName = "CasaOri2"
    └── SpawnPoint (Part) ← Etc...
```

### 3. Configurar BaseTemplate

O **BaseTemplate** deve ser um Model que:
- ✅ Tenha um **PrimaryPart** definido (importante!)
- ✅ Contenha todas as parts da base do jogador
- ✅ Esteja posicionado em `Workspace > Bases`

**Como definir PrimaryPart:**
1. Selecione o Model `BaseTemplate`
2. No Properties, encontre **PrimaryPart**
3. Defina como a Part principal da base (geralmente o chão ou centro)

### 4. Configurar SpawnPoints

Para cada `CasaOri`, crie um **SpawnPoint**:

1. Crie uma **Part** chamada `SpawnPoint`
2. Posicione onde o jogador deve aparecer
3. Adicione um **Attribute**:
   - Nome: `HouseName`
   - Tipo: `String`
   - Valor: `CasaOri1` (correspondente à casa)

**Passos para adicionar atributo:**
1. Selecione a Part SpawnPoint
2. No Properties, vá para **Attributes**
3. Clique no **+** para adicionar
4. Nome: `HouseName`, Valor: `CasaOri1`

## ⚙️ Configurações

No início do script há uma seção `CONFIG` onde você pode ajustar:

```lua
local CONFIG = {
    SMOOTH_TELEPORT = true,  -- true = teleporte suave, false = instantâneo
    TWEEN_TIME = 1.5,        -- Tempo do teleporte suave (segundos)
    CLEANUP_INTERVAL = 300,  -- Limpeza automática (5 minutos)
    DEBUG_LOGS = true        -- Logs detalhados no Output
}
```

## 🎮 Como Funciona

### Para o Jogador:
1. **Ao entrar:** Recebe automaticamente uma base livre
2. **Ao spawnar:** É teleportado para sua base
3. **Comando /home:** Digite no chat para voltar à base
4. **Ao sair:** Base é liberada automaticamente

### Para o Desenvolvedor:
- **Logs claros** no Output Window
- **Prevenção de erros** com verificações
- **Limpeza automática** de bases órfãs
- **Sistema robusto** contra falhas

## 🐛 Solução de Problemas

### "Pasta 'Bases' não encontrada"
- ✅ Certifique-se que existe uma pasta chamada **Bases** no Workspace
- ✅ Verifique se não há erros de digitação no nome

### "BaseTemplate não encontrado"
- ✅ Confirme que existe um Model chamado **BaseTemplate** dentro de Bases
- ✅ Verifique se não está dentro de outra pasta

### "BaseTemplate não possui PrimaryPart"
- ✅ Selecione o BaseTemplate
- ✅ No Properties, defina **PrimaryPart** como uma Part do modelo
- ✅ Geralmente use a Part do chão ou centro da base

### "SpawnPoint não encontrado"
- ✅ Verifique se existe uma Part chamada **SpawnPoint** no mapa
- ✅ Confirme se o atributo **HouseName** está correto
- ✅ Verifique se o valor do HouseName corresponde a uma CasaOri

### "Nenhuma base livre disponível"
- ✅ Adicione mais CasaOri (CasaOri4, CasaOri5, etc.)
- ✅ Crie SpawnPoints correspondentes
- ✅ Verifique se as bases não estão marcadas como ocupadas incorretamente

## 📝 Logs do Sistema

O sistema gera logs claros no **Output Window**:

```
[10:30:15] [BASE_SYSTEM] [INFO] Sistema inicializado com sucesso! Bases disponíveis: 3
[10:30:20] [BASE_SYSTEM] [INFO] Jogador conectado: PlayerName
[10:30:21] [BASE_SYSTEM] [INFO] Base CasaOri1 alocada para PlayerName com sucesso!
[10:30:22] [BASE_SYSTEM] [INFO] Teleportando PlayerName suavemente para sua base
```

## 🔧 Personalização

### Alterar Nomes das Pastas
Se quiser usar nomes diferentes, edite estas linhas no script:

```lua
-- Linha ~67: Alterar nome da pasta principal
basesFolder = Workspace:WaitForChild("MinhasPastas", 10)

-- Linha ~75: Alterar nome do template
baseTemplate = basesFolder:WaitForChild("MeuTemplate", 10)

-- Linha ~106: Alterar padrão dos nomes das casas
if child.Name:match("^MinhaCasa%d+$") then
```

### Adicionar Mais Funcionalidades
O script é modular, você pode facilmente:
- Adicionar novos comandos de chat
- Implementar sistema de permissões
- Adicionar efeitos visuais no teleporte
- Criar sistema de upgrade de bases

## 📊 Limitações Conhecidas

1. **Máximo de bases:** Limitado pelo número de CasaOri criadas
2. **PrimaryPart obrigatório:** BaseTemplate deve ter PrimaryPart definido
3. **SpawnPoints únicos:** Cada CasaOri precisa de seu SpawnPoint
4. **Não persiste:** Bases são perdidas ao reiniciar o servidor

## 🆘 Suporte

Se encontrar problemas:

1. **Verifique os logs** no Output Window
2. **Confirme a estrutura** do Workspace
3. **Teste com um jogador** primeiro
4. **Verifique se o script** está no ServerScriptService (não LocalScript)

## 📄 Licença

Este script é fornecido como está, para uso educacional e em projetos Roblox. Modifique conforme necessário para seu jogo.
