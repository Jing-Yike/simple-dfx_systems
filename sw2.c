#include "ff.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xuartps.h"
#include "xil_types.h"
#include <stdio.h>
#include <stdint.h>

FATFS  fatfs;

int SD_Transfer(char *FileName, u64 distAddr, u64 size){
    FIL fil;
    UINT br;
    FRESULT result;
    xil_printf("Opening %s ", FileName );
    result = f_open(&fil, FileName, FA_READ);
    if ( result ){
        xil_printf("Failed with ERROR: %d \n\r", result);
        return XST_FAILURE;
    }
    xil_printf("... OK\n\r");
    result = f_lseek(&fil, 0);
    if ( result ){
        xil_printf("Moving file pointer of the file object: Failed with ERROR: %d \n\r", result);
        return XST_FAILURE;
    }
    xil_printf("Reading file %s of %llu Bytes to 0x%llx ", FileName, size, distAddr);
    result = f_read(&fil, (void*) distAddr, (UINT)size, &br);
    if ( result ){
        xil_printf(": Failed with ERROR: %d \n\r", result);
        return XST_FAILURE;
    }
    xil_printf("... OK\n\r");
    xil_printf("Closing %s ", FileName);
    result = f_close(&fil);
    if ( result ){
        xil_printf(": Failed with ERROR: %d \n\r", result);
        return XST_FAILURE;
    }
    xil_printf("... OK\n\r");
    return XST_SUCCESS;
}

int SD_Init(){
    static FATFS fatfs;
    FRESULT result;
    xil_printf("Mounting SD ");
    result = f_mount(&fatfs, "", 0);
    if ( result != XST_SUCCESS){
        xil_printf("Failed with ERROR: %d\n\r", result);
        return XST_FAILURE;
    }
    xil_printf("... OK\n\r");
    return XST_SUCCESS;
}

/************************** DDR4 data test function **************************/
// read the first 1024 bytes data of target address after refreshing cache
void TestDDR4Load(u64 address, u64 size) {
    u32 i;
    u8 *ptr = (u8 *) address;
    xil_printf("DDR4 content at 0x%llx:\n\r ", address);
    for (i = 0; i < 1024; i++) {
        xil_printf("%02x ", ptr[i]);
        if ((i + 1) % 16 == 0) {
            xil_printf("\n\r");
        }
    }
    xil_printf("\n\r");
}

/************************** DDR4 data test function (tail) **************************/
void TestDDR4LoadTail(u64 address, u64 size) {
    u32 i;
    u64 num_to_print = (size >= 1024) ? 1024 : (u32)size;
    u64 start_offset  = (size > num_to_print) ? (size - num_to_print) : 0;

    u8 *ptr = (u8 *)address;
    xil_printf("DDR4 content tail at 0x%llx (last %llu bytes):\n\r",
               address + start_offset, num_to_print);

    for (i = 0; i < num_to_print; i++) {
        xil_printf("%02x ", ptr[start_offset + i]);
        if ((i + 1) % 16 == 0) {
            xil_printf("\n\r");
        }
    }
    xil_printf("\n\r");
}

#define DFXC_BASEADDR       0xA0000000U

/* DFX register offset */
#define DFXC_STATUS         (DFXC_BASEADDR + 0x00000)
#define DFXC_CONTROL        (DFXC_BASEADDR + 0x00000)
#define DFXC_SW_TRIGGER     (DFXC_BASEADDR + 0x00004)

#define DFXC_BS_ID0         (DFXC_BASEADDR + 0x000C0)
#define DFXC_BS_ADDRESS0    (DFXC_BASEADDR + 0x000C4)
#define DFXC_BS_SIZE0       (DFXC_BASEADDR + 0x000C8)
#define DFXC_BS_ID1         (DFXC_BASEADDR + 0x000D0)
#define DFXC_BS_ADDRESS1    (DFXC_BASEADDR + 0x000D4)
#define DFXC_BS_SIZE1       (DFXC_BASEADDR + 0x000D8)
#define DFXC_BS_ID2         (DFXC_BASEADDR + 0x000E0)
#define DFXC_BS_ADDRESS2    (DFXC_BASEADDR + 0x000E4)
#define DFXC_BS_SIZE2       (DFXC_BASEADDR + 0x000E8)
#define DFXC_BS_ID3         (DFXC_BASEADDR + 0x000F0)
#define DFXC_BS_ADDRESS3    (DFXC_BASEADDR + 0x000F4)
#define DFXC_BS_SIZE3       (DFXC_BASEADDR + 0x000F8)

/* CONTROL register */
#define DFXC_SHUTDOWN               0
#define DFXC_RESTART_WITH_NO_STATUS 1

/* DDR base address under PS */
#define PS_DDR_BASE 0x400000000ULL

/* Size and Address of the bitstreams */
#define C_DOWN_ADDR  0x404000000ULL
#define C_DOWN_SIZE  666088ULL
#define C_UP_ADDR    0x403000000ULL
#define C_UP_SIZE    666088ULL
#define S_LEFT_ADDR  0x402000000ULL
#define S_LEFT_SIZE  655968ULL
#define S_RIGHT_ADDR 0x401000000ULL
#define S_RIGHT_SIZE 655968ULL

/* UART device ID (For initialization of XUartPs) */
#define UART_DEVICE_ID XPAR_XUARTPS_0_DEVICE_ID

/* Simple blocking read of a single character from UART（Using XUartPs API） */
static XUartPs Uart_Ps;

static char uart_getchar_blocking(void) {
    u8 c = 0;
    int received = 0;
    while (!received) {
        received = XUartPs_Recv(&Uart_Ps, &c, 1); /* Return the number of bytes received */
    }
    return (char)c;
}

/* Convert PS address to DFX viewpoint offset (32-bit) */
static u32 ps_to_dfx_offset(u64 ps_addr) {
    u64 off = ps_addr - PS_DDR_BASE;
    return (u32)(off & 0xFFFFFFFFU); 
}

/* Poll STATUS, waiting for STATE == 0b111 or timeout. Return 0 indicates success; non-zero indicates failure/timeout. */
static int wait_for_dfx_done(u32 timeout_loops) {
    u32 loops = 0;
    while (loops++ < timeout_loops) {
        u32 status = Xil_In32(DFXC_STATUS);
        u32 state = status & 0x7;          /* STATE bits[2:0] */
        u32 error = (status >> 3) & 0xF;   /* ERROR bits[6:3] (example) */
        if (error) {
            xil_printf("DFX reported error (STATUS=0x%08x)\n\r", status);
            return -2;
        }
        if (state == 0x7) {
            /* Loading complete */
            xil_printf("DFX load complete (STATUS=0x%08x)\n\r", status);
            return 0;
        }
    }
    xil_printf("DFX wait timeout\n\r");
    return -1;
}

/* ---------- Debug Function: Print DFX Key Registers ---------- */
static void dump_dfx_regs(void) {
    xil_printf("=== DFX REG DUMP ===\n\r");
    xil_printf("DFXC_STATUS = 0x%08x\n\r", Xil_In32(DFXC_STATUS));
    xil_printf("DFXC_CONTROL = 0x%08x\n\r", Xil_In32(DFXC_CONTROL));
    xil_printf("DFXC_SW_TRIGGER = 0x%08x\n\r", Xil_In32(DFXC_SW_TRIGGER));
    xil_printf("BS_ID0 = 0x%08x, BS_ADDR0 = 0x%08x, BS_SIZE0 = 0x%08x\n\r",
               Xil_In32(DFXC_BS_ID0), Xil_In32(DFXC_BS_ADDRESS0), Xil_In32(DFXC_BS_SIZE0));
    xil_printf("BS_ID1 = 0x%08x, BS_ADDR1 = 0x%08x, BS_SIZE1 = 0x%08x\n\r",
               Xil_In32(DFXC_BS_ID1), Xil_In32(DFXC_BS_ADDRESS1), Xil_In32(DFXC_BS_SIZE1));
    xil_printf("BS_ID2 = 0x%08x, BS_ADDR2 = 0x%08x, BS_SIZE2 = 0x%08x\n\r",
               Xil_In32(DFXC_BS_ID2), Xil_In32(DFXC_BS_ADDRESS2), Xil_In32(DFXC_BS_SIZE2));
    xil_printf("BS_ID3 = 0x%08x, BS_ADDR3 = 0x%08x, BS_SIZE3 = 0x%08x\n\r",
               Xil_In32(DFXC_BS_ID3), Xil_In32(DFXC_BS_ADDRESS3), Xil_In32(DFXC_BS_SIZE3));
    xil_printf("=====================\n\r");
}

/* Main Program */
int main(){
    int Status;

    /* Initialize UART (XUartPs) for receiving user input */
    XUartPs_Config *UartCfg;
    UartCfg = XUartPs_LookupConfig(UART_DEVICE_ID);
    if (UartCfg == NULL) {
        xil_printf("UART LookupConfig failed\n\r");
        return XST_FAILURE;
    }
    Status = XUartPs_CfgInitialize(&Uart_Ps, UartCfg, UartCfg->BaseAddress);
    if (Status != XST_SUCCESS) {
        xil_printf("UART CfgInitialize failed\n\r");
        return XST_FAILURE;
    }
    XUartPs_SetBaudRate(&Uart_Ps, 115200);

    /* Initialize the SD card file system and load 4 partial bitstreams to the specified PS DDR address. */
    Status = SD_Init();
    if (Status != XST_SUCCESS) {
        xil_printf("file system init failed\n\r");
        return XST_FAILURE;
    }

    xil_printf("Loading bitstreams from SD to DDR...\n\r");

    Status = SD_Transfer("c_down.bin", C_DOWN_ADDR, C_DOWN_SIZE);
    if (Status != XST_SUCCESS) { xil_printf("file read failed\n\r"); return XST_FAILURE; }
    /* flush cache so PL will see the written data */
    Xil_DCacheFlushRange((UINTPTR)C_DOWN_ADDR, (u32)C_DOWN_SIZE);
    TestDDR4LoadTail(C_DOWN_ADDR, C_DOWN_SIZE);

    Status = SD_Transfer("c_up.bin", C_UP_ADDR, C_UP_SIZE);
    if (Status != XST_SUCCESS) { xil_printf("file read failed\n\r"); return XST_FAILURE; }
    Xil_DCacheFlushRange((UINTPTR)C_UP_ADDR, (u32)C_UP_SIZE);
    TestDDR4LoadTail(C_UP_ADDR, C_UP_SIZE);

    Status = SD_Transfer("s_left.bin", S_LEFT_ADDR, S_LEFT_SIZE);
    if (Status != XST_SUCCESS) { xil_printf("file read failed\n\r"); return XST_FAILURE; }
    Xil_DCacheFlushRange((UINTPTR)S_LEFT_ADDR, (u32)S_LEFT_SIZE);
    TestDDR4LoadTail(S_LEFT_ADDR, S_LEFT_SIZE);

    Status = SD_Transfer("s_right.bin", S_RIGHT_ADDR, S_RIGHT_SIZE);
    if (Status != XST_SUCCESS) { xil_printf("file read failed\n\r"); return XST_FAILURE; }
    Xil_DCacheFlushRange((UINTPTR)S_RIGHT_ADDR, (u32)S_RIGHT_SIZE);
    TestDDR4LoadTail(S_RIGHT_ADDR, S_RIGHT_SIZE);

    xil_printf("All bitstreams loaded to DDR. Entering interactive menu.\n\r");

/* Enable ICAP and disable PCAP */
#define CSU_PCAP_CTRL 0xFFCA3008U
    u32 val = Xil_In32(CSU_PCAP_CTRL);
    val &= ~0x1U;
    Xil_Out32(CSU_PCAP_CTRL, val);

    /* Interactive Menu: Can be triggered repeatedly */
    while (1) {
        xil_printf("\n\r=== DFX Trigger Menu ===\n\r");
        xil_printf("1 - load s_left (RM0)\n\r");
        xil_printf("2 - load s_right (RM1)\n\r");
        xil_printf("3 - load c_up (RM2)\n\r");
        xil_printf("4 - load c_down (RM3)\n\r");
        xil_printf("q - quit\n\r");
        xil_printf("Enter selection: ");

        char c = uart_getchar_blocking();
        xil_printf("%c\n\r", c); /* echo */

        if (c == 'q' || c == 'Q') {
            xil_printf("Exiting menu.\n\r");
            break;
        }

        u64 ps_addr = 0;
        u64 size = 0;
        u32 rm_id = 0xFFFFFFFF;

        if (c == '1') {
            ps_addr = S_LEFT_ADDR; size = S_LEFT_SIZE; rm_id = 0;
            xil_printf("Triggering s_left (RM0)\n\r");
        } else if (c == '2') {
            ps_addr = S_RIGHT_ADDR; size = S_RIGHT_SIZE; rm_id = 1;
            xil_printf("Triggering s_right (RM1)\n\r");
        } else if (c == '3') {
            ps_addr = C_UP_ADDR; size = C_UP_SIZE; rm_id = 2;
            xil_printf("Triggering c_up (RM2)\n\r");
        } else if (c == '4') {
            ps_addr = C_DOWN_ADDR; size = C_DOWN_SIZE; rm_id = 3;
            xil_printf("Triggering c_down (RM3)\n\r");
        } else {
            xil_printf("Invalid selection\n\r");
            continue;
        }

        /* Calculate DFX perspective offset (DDR addresses seen by the DFX Controller start at 0) */
        u32 dfx_addr = ps_to_dfx_offset(ps_addr);
        u32 dfx_size = (u32)size; 

        /* Print the register before writing and the value to be written for debugging purposes. */
		xil_printf("About to write: PS_ADDR=0x%llx, DFX_ADDR=0x%08x, SIZE=%u, RM=%u\n\r",
				   ps_addr, dfx_addr, dfx_size, rm_id);
		dump_dfx_regs();

		/* Write Process: SHUTDOWN -> Write Address/Size -> small delay -> RESTART -> dump -> TRIGGER */
		Xil_Out32(DFXC_CONTROL, DFXC_SHUTDOWN);

        switch (rm_id) {
            case 0:
                Xil_Out32(DFXC_BS_ADDRESS0, dfx_addr);
                Xil_Out32(DFXC_BS_SIZE0, dfx_size);
                break;
            case 1:
                Xil_Out32(DFXC_BS_ADDRESS1, dfx_addr);
                Xil_Out32(DFXC_BS_SIZE1, dfx_size);
                break;
            case 2:
                Xil_Out32(DFXC_BS_ADDRESS2, dfx_addr);
                Xil_Out32(DFXC_BS_SIZE2, dfx_size);
                break;
            case 3:
                Xil_Out32(DFXC_BS_ADDRESS3, dfx_addr);
                Xil_Out32(DFXC_BS_SIZE3, dfx_size);
                break;
            default:
                xil_printf("Invalid RM id\n\r");
                continue;
        }

		Xil_Out32(DFXC_CONTROL, DFXC_RESTART_WITH_NO_STATUS);

		dump_dfx_regs();

		/* Trigger */
		Xil_Out32(DFXC_SW_TRIGGER, rm_id);
		xil_printf("SW_TRIGGER written (rm=%u). Polling status...\n\r", rm_id);

        /* Wait for completion */
        int rc = wait_for_dfx_done(5000000U);
        if (rc == 0) {
            xil_printf("RM %u reconfiguration success.\n\r", rm_id);
        } else {
            xil_printf("RM %u reconfiguration failed (rc=%d).\n\r", rm_id, rc);
            /* Read the register again to check the status */
			dump_dfx_regs();
        }
    }


    xil_printf("Program finished.\n\r");
    return 0;
}
