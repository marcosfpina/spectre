#!/usr/bin/env bash
# Clone all domain projects from GitHub to ~/dev/low-level/

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Target directory
TARGET_DIR="${HOME}/dev/low-level"

# Project mappings (project:github_user)
declare -A PROJECT_OWNERS=(
    ["ai-agent-os"]="marcosfpina"
    ["arch-analyzer"]="VoidNxSEC"
    ["cognitive-vault"]="VoidNxSEC"
    ["intelagent"]="marcosfpina"
    ["ml-offload-api"]="VoidNxSEC"
    ["ragtex"]="NOTFOUND"
    ["securellm-bridge"]="VoidNxSEC"
)

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Cloning SPECTRE Domain Projects${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Create target directory if it doesn't exist
mkdir -p "${TARGET_DIR}"

# Clone each project
for PROJECT in "${!PROJECT_OWNERS[@]}"; do
    PROJECT_PATH="${TARGET_DIR}/${PROJECT}"
    OWNER="${PROJECT_OWNERS[$PROJECT]}"

    if [ -d "${PROJECT_PATH}" ]; then
        echo -e "${YELLOW}[SKIP]${NC} ${PROJECT} already exists at ${PROJECT_PATH}"
    elif [ "${OWNER}" = "NOTFOUND" ]; then
        echo -e "${RED}[ERROR]${NC} ❌ ${PROJECT} - Repo not found on GitHub"
    else
        echo -e "${BLUE}[CLONING]${NC} ${PROJECT} from ${OWNER}..."

        # Clone from GitHub
        if gh repo clone "${OWNER}/${PROJECT}" "${PROJECT_PATH}" 2>/dev/null; then
            echo -e "${GREEN}[SUCCESS]${NC} ✅ Cloned ${PROJECT}"
        else
            echo -e "${RED}[ERROR]${NC} ❌ Failed to clone ${PROJECT} from ${OWNER}"
            echo -e "${YELLOW}[INFO]${NC} Trying git clone instead..."

            # Fallback to git clone
            if git clone "git@github.com:${OWNER}/${PROJECT}.git" "${PROJECT_PATH}" 2>/dev/null; then
                echo -e "${GREEN}[SUCCESS]${NC} ✅ Cloned ${PROJECT} via git"
            else
                echo -e "${RED}[ERROR]${NC} ❌ Failed to clone ${PROJECT}"
            fi
        fi
    fi
    echo ""
done

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}[DONE]${NC} Clone operation completed!"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}[INFO]${NC} Projects cloned to: ${TARGET_DIR}"
echo -e "${BLUE}[INFO]${NC} To verify: ls -la ${TARGET_DIR}"
echo ""
echo -e "${YELLOW}[NOTE]${NC} ragtex not found on GitHub - you may need to clone manually"
