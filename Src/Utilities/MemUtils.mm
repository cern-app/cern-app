#import <mach/mach_host.h>
#import <mach/mach.h>

#import "MemUtils.h"

namespace CernAPP {

//________________________________________________________________________________________
void print_memory_usage()
{
   //Taken from http://stackoverflow.com/questions/5012886/knowing-available-ram-on-an-ios-device
   //Modified by me.
   
   const mach_port_t host_port = mach_host_self();
   vm_size_t pageSize = {};//hehehe, modern C++!!!
   host_page_size(host_port, &pageSize);

   vm_statistics_data_t vmStat = {};
   mach_msg_type_number_t hostSize = sizeof(vm_statistics_data_t) / sizeof(integer_t);
   if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vmStat, &hostSize) != KERN_SUCCESS) {
      NSLog(@"Failed to fetch vm statistics");
      return;
   }

   //Stats in bytes.
   const natural_t memUsed = (vmStat.active_count + vmStat.inactive_count + vmStat.wire_count) * pageSize;
   const natural_t memFree = vmStat.free_count * pageSize;
   const natural_t memTotal = memUsed + memFree;
   NSLog(@"used: %u free: %u total: %u", memUsed, memFree, memTotal);
}

}
