#include "Config.h"

namespace sfz {
namespace config {
    bool loadInRam { false };
    int numBackgroundThreads { 4 };
    float stealingAgeCoeff { 0.5f };
    float stealingPowerCoeff { 0.5f };
    int filterControlInterval { 16 };
    unsigned delayedReleaseVoices { 16 };
}
}
