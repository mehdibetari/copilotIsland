# Copilot Island

Application macOS (agent de barre de menus, sans icône dans le Dock) qui affiche l'état de vos sessions GitHub Copilot CLI dans une « île » et permet de revenir à l'onglet iTerm2 de la session.

## Aperçu

- Au repos, l'île épouse l'encoche du MacBook (comme une Dynamic Island) et affiche un point par session, coloré selon son état.
- Une pastille orange (action requise) ou verte (tâche terminée) signale qu'une session attend une interaction.
- Au survol, l'île s'agrandit avec une animation fluide et liste les sessions ; un clic sur une session ramène à son onglet iTerm2.

## Prérequis

- macOS 14+
- Swift 5.9+ (Xcode ou Command Line Tools)
- iTerm2 (pour le retour à l'onglet de session)
- `curl` (utilisé par le hook)

## Fonctionnement

1. Des hooks Copilot CLI envoient chaque événement (`sessionStart`, `sessionEnd`, `userPromptSubmitted`, `postToolUse`, `notification`, `agentStop`) en HTTP à `http://127.0.0.1:47615/event`.
2. L'app écoute sur ce port et met à jour l'île.
3. L'en-tête `X-Iterm-Session` permet de réactiver le bon onglet iTerm2 (autorisation d'automatisation demandée au premier usage).

## Installation

### 1. Compiler l'app et l'installer dans /Applications

```bash
scripts/build-app.sh --install
```

Le script :
- compile en release (`swift build -c release`) ;
- génère l'icône (`scripts/make-icon.swift` → `AppIcon.icns`) ;
- crée `build/CopilotIsland.app` et la signe en ad hoc ;
- avec `--install` : arrête l'app en cours, la copie dans `/Applications/CopilotIsland.app`.

Sans `--install`, seule `build/CopilotIsland.app` est produite.

### 2. Installer les hooks Copilot CLI

```bash
scripts/install-hooks.sh
```

Installe `copilot-island-hook.sh` et `copilot-island.json` dans `~/.copilot/hooks` (ou `$COPILOT_HOME/hooks`), au niveau utilisateur donc pour tous les dépôts. **Relancez ensuite vos sessions Copilot CLI.**

## Lancer l'app

- Depuis Launchpad ou Spotlight : « CopilotIsland ».
- Ou en terminal :

```bash
open /Applications/CopilotIsland.app
# ou, sans installation :
open build/CopilotIsland.app
```

Vérifier qu'elle tourne :

```bash
pgrep -fl CopilotIsland
```

Arrêter :

```bash
pkill -x CopilotIsland
```

## Mettre à jour

Après une modification du code :

```bash
scripts/build-app.sh --install
open /Applications/CopilotIsland.app
```

Si Launchpad/Finder affichent une ancienne icône, c'est le cache de macOS (`killall Dock Finder` pour le rafraîchir).

## Structure

| Chemin | Rôle |
|---|---|
| `Sources/CopilotIsland/` | Code Swift (serveur de hooks, store de sessions, vue, intégration iTerm) |
| `hooks/copilot-island-hook.sh` | Transmet le payload du hook à l'app |
| `scripts/build-app.sh` | Build, icône, bundle `.app`, installation |
| `scripts/make-icon.swift` | Génère l'icône de l'app |
| `scripts/install-hooks.sh` | Installe les hooks Copilot CLI |
| `build/` | Sortie de build (`CopilotIsland.app`) |

## Dépannage

- **Rien ne s'affiche** : vérifiez que l'app tourne et que les hooks sont installés, puis relancez la session Copilot CLI.
- **Port occupé** : l'app utilise `127.0.0.1:47615` ; vérifiez avec `lsof -iTCP:47615 -sTCP:LISTEN`.
- **Le retour iTerm2 ne marche pas** : autorisez CopilotIsland dans Réglages Système → Confidentialité et sécurité → Automatisation.
- **Test manuel du hook** : `echo '{}' | ~/.copilot/hooks/copilot-island-hook.sh sessionStart`

## Licence

[PolyForm Noncommercial 1.0.0](LICENSE) : utilisation, modification et partage libres pour tout usage non commercial. Toute utilisation commerciale est interdite.
