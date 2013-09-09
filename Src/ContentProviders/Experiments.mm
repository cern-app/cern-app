#import <cassert>

#import "Experiments.h"

namespace CernAPP {

//I'm using string literals not to care about
//ARC and NSStrings.
const char * experimentNames[(int)LHCExperiment::nExperiments] = {
   "ATLAS",
   "CMS",
   "ALICE",
   "LHCb",
   "LHC",
   "AMS"
};

//________________________________________________________________________________________
const char *ExperimentName(LHCExperiment experiment)
{
   const unsigned n = unsigned(experiment);
   assert(n < unsigned(LHCExperiment::nExperiments) && "ExperimentName, bad experiment id");
   
   return experimentNames[n];
}

//________________________________________________________________________________________
LHCExperiment ExperimentNameToEnum(NSString *name)
{
   assert(name != nil && "ExperimentNameToEnum, parameter 'name' is nil");
   
   if ([name isEqualToString : @"ATLAS"])
      return LHCExperiment::ATLAS;
   else if ([name isEqualToString : @"CMS"])
      return LHCExperiment::CMS;
   else if ([name isEqualToString : @"ALICE"])
      return LHCExperiment::ALICE;
   else if ([name isEqualToString : @"LHCb"])
      return LHCExperiment::LHCb;
   else if ([name isEqualToString : @"AMS"])
      return LHCExperiment::AMS;

   assert([name isEqualToString : @"LHC"] &&
          "ExperimentNameToEnum, unknown experiment");

   return LHCExperiment::LHC;
}

}
