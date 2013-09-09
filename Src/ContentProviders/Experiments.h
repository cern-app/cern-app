#import <Foundation/Foundation.h>

namespace CernAPP {

enum class LHCExperiment : unsigned {
   ATLAS,
   CMS,
   ALICE,
   LHCb,
   LHC,//That's not an experiment actually, but we treat it as an experiment in CERN LIVE.
   AMS,
   nExperiments
};

const char *ExperimentName(LHCExperiment experiment);
LHCExperiment ExperimentNameToEnum(NSString *name);

}
