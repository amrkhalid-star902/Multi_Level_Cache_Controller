`timescale 1ns / 1ps



module cache_controller(
    address,clk,data,mode,output_data,
    hit1,hit2,Wait,clk2,Anode_activate,seven_seg_out
    );
    parameter no_of_adress_bits=11;
    parameter no_of_blkoffset_bits=2; // Once we find line in the cache the block offset tells us which block to read
    parameter byte_size=4;  // 0ne block is 4 bits
    
    /*****************/
    
    parameter no_of_L2_ways=4; // l2 is 4-way set associative
    parameter no_of_L2_ways_bits=2; // 4 ways can be represented by 2bits
    parameter no_of_L2_blocks=16;   // there is 4 cache lines in l2 block each line has 4 blocks
    parameter no_of_bytes_L2_block=16; //No.of bytes in l2 cache line =4* bytes in a block=4*4=16
    parameter L2_block_bit_size=64;    //No of bits in l2 cache line  =4*no. of bytes =4*16=64
    parameter no_of_L2_index_bits=4;   //l2 cache has 16 blocks so 2^4 is required to index them
    parameter no_of_L2_tag_bits=5;     // tagbitsnumber=addresssize-index_bits-offset_bits=11-4-2=5
    
    /****************/
    parameter no_of_L1_blocks=8; // No of lines in l1 cache equal No of blocks as l1 is direct mapped
    parameter no_of_bytes_L1_block=4;  //each block has 4 bytes
    parameter L1_block_bit_size=16;
    parameter no_of_L1_index_bits=3; // l1 has 8 blocks so 2^3 is required to index them
    parameter no_of_L1_tag_bits=6;   //tagbitsnumber=addresssize-index_bits-offset_bits=11-3-2=6
    
    /**************/
    
    parameter no_of_main_memory_blocks=32;
    parameter main_memory_block_size=16;  //Each Line has One block and each block have 4 bytes total no.of bits =1*4*4=16  
    parameter no_of_bytes_main_memory_block=4;
    parameter main_memory_total_bytes=128; // main memory have 32 lines each line have 4 bytes
    
    /*************/
    parameter L1_latency=1;      // It represent delay in fetching data from l1 cache 1 indicate that data may be available after 1 clock cycle
    parameter L2_latency=2;
    parameter main_memory_latency=5;
    
    /**************/
    
    input [no_of_adress_bits-1:0] address;
    input clk;
    input [byte_size-1:0]data;
    input mode;   //mode=0 : Read     mode=1 : Write
    output reg [byte_size-1:0]output_data;
    output reg hit1,hit2;
    output reg Wait;     //Wait=1 is a signal for the processor...that the cache controller is currently working on some read/write operation and processor needs to wait before the controller accepts next read/write operation
    output reg [3:0] Anode_activate;
    output reg [6:0] seven_seg_out;
    /*************/
    reg [no_of_adress_bits-1:0] address_valid; //To check wether is a stored line in cache or not
    reg [no_of_adress_bits-no_of_blkoffset_bits-1:0]main_memory_blk_id;  //Represents the line number to which the address belongs on main memory
    reg [no_of_L1_tag_bits-1:0]L1_tag; //The tag for lines on L1 Cache
    reg [no_of_L1_index_bits-1:0] L1_index; //Represents the index of the line to which the address belongs on L1 Cache
    reg [no_of_L2_tag_bits-1:0]L2_tag; //the tag for L2 cache
    reg [no_of_L2_index_bits-1:0] L2_index; //The index of the line to which the address belongs on L2 Cache
    reg [no_of_blkoffset_bits-1:0] offset; //Offset gives the index of byte within a block
    
    /***************/
    
    //integer values for working in for loop
    integer i;
    integer j;
    
    /**************/
    //the variable given below in various search operation in L1 , L2 and main memory
    //specially when we need to evict some block from L1 or L2 Cache
    //then it needs to be searched in the L2 or in main memory to update its value there
    
    integer L2_check;
    integer L2_check2;
    integer L2_checka;
    integer L2_check2a;
    integer L2_mm_check;     //mm=main memory
    integer L2_mm_check2;
    integer L2_mm_iterator;
    integer L2_iterator;
    
    integer L1_L2_check;
    integer L1_L2_check2;
    integer L1_L2_checka;
    integer L1_L2_check2a;
    integer L1_L2_checkb;
    integer L1_L2_check2b;
    
    /*************/
    //Many times we need to evict an block from L1 or L2 Cache..
    //so its value needs to be updated in L2 or main Memory
    //these are the variable used for evicting operations
    //for finding the block present in L1 or L2..its location in L2 or main memory
    
    reg [no_of_L2_ways_bits-1:0]lru_value;  // Least Recentelly used value
    reg [no_of_L2_ways_bits-1:0]lru_value_dummy;
    
    reg [no_of_L2_ways_bits-1:0]lru_value2;
    reg [no_of_L2_ways_bits-1:0]lru_value_dummy2;
    
    reg [no_of_L1_tag_bits-1:0]L1_evict_tag;
    reg [no_of_L2_tag_bits-1:0]L1_to_L2_tag;
    reg [no_of_L2_index_bits-1:0]L1_to_L2_index;
    
    reg [no_of_L1_tag_bits-1:0]L1_evict_tag2;
    reg [no_of_L2_tag_bits-1:0]L1_to_L2_tag2;
    reg [no_of_L2_index_bits-1:0]L1_to_L2_index2; 
    
    reg [no_of_L1_tag_bits-1:0]L1_evict_tag3;
    reg [no_of_L2_tag_bits-1:0]L1_to_L2_tag3;
    reg [no_of_L2_index_bits-1:0]L1_to_L2_index3;
    
    reg [no_of_L2_tag_bits-1:0]L2_evict_tag;
    
    /*************/
    //to store whether the block to be evicted was found in L2 or main memory or not
    
    reg L1_to_L2_search;
    reg L1_to_L2_search2;
    reg L1_to_L2_search3;
    
    /************/
    //Variables for implementing slow clock 
    output reg clk2;   //slow clock signal
    reg [31:0] counter=0;  // A counter variable to implement slow clock
    
    /**********/
    //for the delay counters to implement delays in the L2 Cache
    
    reg[1:0] L2_delay_counter=0;
    reg[3:0] main_memory_delay_counter=0;
    reg dummy_hit;
    reg is_L2_delay=0;
    
    /**********/
    //for the delay counters to implement delays in the main memory
    
    reg[1:0] L2_delay_counter_w=0;
    reg [3:0] main_memory_delay_counter_w=0;
    reg dummy_hit_w=0;
    reg is_L2_delay_w=0;
    
    /*********/
    
    //for the delay counters to implement delays in the main memorys
    
    reg[no_of_adress_bits-1:0] stored_address;
    reg stored_mode;
    reg [byte_size-1:0] stored_data;
    reg Ccount=0;
    
    // Main Memory instance
    
    reg[main_memory_block_size-1:0] main_memory[0:no_of_main_memory_blocks-1];
    
    initial
    begin : initialization_main_memory
    
        integer i;
        for(i=0 ; i<no_of_main_memory_blocks ;i=i+1)
        begin
            main_memory[i]=i;
        end
     end
    
    // L1 cache instance
    reg[L1_block_bit_size-1:0] L1_cache_memory [0:no_of_L1_blocks-1];
    reg[no_of_L1_tag_bits-1:0] L1_tag_array[0:no_of_L1_blocks-1];
    reg L1_valid[0:no_of_L1_blocks-1];
    
    initial
    begin: initialization_L1
        integer i;
        for(i=0;i<no_of_L1_blocks;i=i+1)
        begin
            L1_valid[i]=1'b0;
            L1_tag_array[i]=0;
         end
    end
    
    
    // L2 cache instance
    
    reg[L2_block_bit_size-1:0] L2_cache_memory[0:no_of_L2_blocks-1];
    reg [(no_of_L2_tag_bits*no_of_L2_ways)-1:0] L2_tag_array[0:no_of_L2_blocks-1];
    reg [no_of_L2_ways-1:0] L2_valid[0:no_of_L2_blocks-1];
    reg [no_of_L2_ways*no_of_L2_ways_bits-1:0]lru[0:no_of_L2_blocks-1]; 
                                                                        
    initial
    begin:initialization_L2
        integer i;
        for(i=0;i<no_of_L2_blocks;i=i+1)
        begin
            L2_valid[i]=0;
            L2_tag_array[i]=0;
            lru[i]=8'b11100100;
    
        end
    end                                                                  
             
             
    // Variables for 7-segment display
    
    reg [15:0] seg_display_custom_no;       //the cutom number formed by concatenating the 4 BCD numbers for the 4 LEDs
    reg [3:0]  digit_bcd;                   // The BCD for a digit
    reg [1:0]  anode_no;                    //THe high or low for a 7 segment display
    reg [19:0] refresh;                     // //The counter for activating the four 7 segment displays one by one
    
    
    reg [3:0] a1;                          // BCD for first 7 segment display
    reg [3:0] a2;                          // BCD for second 7 segement display
    reg [3:0] a3;                          // BCD for third  7 segement display
    reg [3:0] a4;                          // BCD for fourth 7 segment display 
    
    
    // Always block for implementing slow clock and BCD display
    always@(posedge clk)
    begin
        a1=(output_data >9)?1:0;
        a2=output_data%10;
        a3=(data >9)?1:0;
        a4=data%10;
        
        seg_display_custom_no={a1,a2,a3,a4};
        refresh <= refresh+1;
        anode_no=refresh[19:18];
        
        case(anode_no)
            2'b00:begin
                Anode_activate=4'b0111;
                //LED 1 is active and other LEDS are off
                digit_bcd=seg_display_custom_no[15:12];
                
            end
        
        
            2'b01:begin
                Anode_activate=4'b1011;
                //LED 2 is active and other LEDS are off
                digit_bcd=seg_display_custom_no[11:8];                           
            
            end
            
            2'b10:begin
                 Anode_activate=4'b1101;
                 //LED 3 is active and other LEDS are off
                 digit_bcd=seg_display_custom_no[7:4];
            
            end
            
            2'b11:begin
                 Anode_activate=4'b1110;
                 //LED 4 is active and other LEDS are off
                 digit_bcd=seg_display_custom_no[3:0];
            
            end
                    
        endcase
        
        
        case(digit_bcd)
            4'b0000: seven_seg_out=7'b1000000; //0
            4'b0001: seven_seg_out=7'b1111001; //1
            4'b0010: seven_seg_out=7'b0100100; //2
            4'b0011: seven_seg_out=7'b0110000; //3
            4'b0100: seven_seg_out=7'b0011001; //4
            4'b0101: seven_seg_out=7'b0010010; //5
            4'b0110: seven_seg_out=7'b0000010; //6
            4'b0111: seven_seg_out=7'b1111000; //7
            4'b1000: seven_seg_out=7'b0000000; //8
            4'b1001: seven_seg_out=7'b0010000; //9
        
        
        endcase
        
        // SLOW CLOCK GENERATOR
        
        counter <= counter+1;
        if(counter ==10)
        begin
            clk2 <= ~clk2;
            counter <=0;
        end
    
    end    
    
    always@(posedge clk2)
    begin
        if(Ccount==0 || Wait==0)
        begin
            stored_address=address;
            Ccount=1;
            stored_mode=mode;
            stored_data=data;
         end
         main_memory_blk_id=(stored_address >> no_of_blkoffset_bits )% no_of_main_memory_blocks;
         L2_index=main_memory_blk_id%no_of_L2_blocks;
         L2_tag=main_memory_blk_id >> no_of_L2_index_bits;
         
         L1_index=main_memory_blk_id%no_of_L1_blocks;
         L1_tag=main_memory_blk_id >> no_of_L1_index_bits;
         offset=stored_address%no_of_bytes_main_memory_block;
         
         if( stored_mode == 0)
         begin
            $display("Check Started");
            /**************************************************************************************************************************************/
            if(L1_valid[L1_index] && L1_tag_array[L1_index] == L1_tag)
            begin
                $display("Found in L1 Cache");
                output_data=L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size];   //a=[x-:y]=[x:x-y+1]
                hit1=0;
                hit2=0;
                Wait=0;
            
            end
            /**************************************************************************************************************************************/
            else
            begin
                $display("Not Found in L1 Cache");
                hit1=0;
                if(L2_delay_counter <L2_latency && is_L2_delay == 0)
            begin
                hit2=0;
                hit1=0;
                L2_delay_counter=L2_delay_counter+1;
                Wait=1;
            end
            else
            begin
               L2_delay_counter=0;
               hit1=0;
               hit2=1;
               Wait=0;
               dummy_hit=0;
               for(L2_check=0;L2_check < no_of_L2_ways;L2_check=L2_check+1)
               begin
                 if(L2_valid[L2_index][L2_check] && L2_tag_array[L2_index][((L2_check+1)*no_of_L2_tag_bits-1)-:no_of_L2_tag_bits]==L2_tag)
                 begin
                     dummy_hit=1;
                     L2_check2=L2_check;
                 end
               end 
               if(dummy_hit == 1) $display("Found in L2 Cache");
               else $display("Not Found in L2 Cache");
               if(dummy_hit == 1)
               begin
                   lru_value2=lru[L2_index][((L2_check2+1)*no_of_L2_ways_bits-1)-:no_of_L2_ways_bits];
                   for(L2_iterator=0;L2_iterator < no_of_L2_ways;L2_iterator=L2_iterator+1)
                   begin
                       lru_value_dummy2=lru[L2_index][((L2_iterator+1)*no_of_L2_ways_bits-1)-:no_of_L2_ways_bits];
                       if(lru_value_dummy2 > lru_value2)
                       begin
                           lru[L2_index][((L2_iterator+1)*no_of_L2_ways_bits-1)-:no_of_L2_ways_bits]=lru_value_dummy2-1; 
                       end 
                   end    
                       lru[L2_index][((L2_check2+1)*no_of_L2_ways_bits-1)-:no_of_L2_ways_bits]=no_of_L2_ways-1;
                       if(L1_valid[L1_index] == 0)
                       begin
                            L1_cache_memory[L1_index]=L2_cache_memory[L2_index][((L2_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size-1];
                            L1_valid[L1_index]=1;
                            L1_tag_array[L1_index]=L1_tag;
                            output_data=L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size];
                            dummy_hit=1;
                       end
                       else
                       begin
                            L1_evict_tag2=L1_tag_array[L1_index];
                            L1_to_L2_tag2=L1_evict_tag2 >>(no_of_L1_tag_bits-no_of_L2_tag_bits);
                            L1_to_L2_index2={L1_evict_tag2[no_of_L1_tag_bits-no_of_L2_tag_bits-1:0],L1_index};
                            L1_to_L2_search2=0;
                            for(L1_L2_checka=0;L1_L2_checka <no_of_L2_ways;L1_L2_checka=L1_L2_checka+1)
                            begin
                                if(L2_valid[L1_to_L2_index2][L1_L2_checka] && L2_tag_array[L1_to_L2_index2][((L1_L2_checka+1)*no_of_L2_tag_bits-1)-:no_of_L2_tag_bits] == L1_to_L2_tag2)
                                begin
                                    L1_to_L2_search2=1;
                                    L1_L2_check2a=L1_L2_checka;
                                end
                            end
                            if(L1_to_L2_search2==1)
                            begin
                                $display("Found L1 eviction in L2");
                                L2_cache_memory[L1_to_L2_index2][((L1_L2_check2a+1)*L1_block_bit_size-1)-:L1_block_bit_size]=L1_cache_memory[L1_index];
                                
                                L1_cache_memory[L1_index]=L2_cache_memory[L2_index][((L2_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size];
                                
                                L1_valid[L1_index]=1;
                                L1_tag_array[L1_index]=L1_tag;
                                
                                output_data=L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size];
                                dummy_hit=1;
                            
                            end
                            else
                            begin
                                main_memory[{L1_evict_tag2,L1_index}]=L1_cache_memory[L1_index];
                                L1_cache_memory[L1_index]=L2_cache_memory[L2_index][((L2_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size];
                                L1_valid[L1_index]=1;
                                L1_tag_array[L1_index]=L1_tag;
                                output_data=L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size];
                                dummy_hit=1;
                                                           
                            
                            end
                                
                       
                       end

                   end
                
                /***************************************************************************/
                else   //dummy_hit=0 (not found in L2 cache)
                begin
                    hit1=0;
                    hit2=0;
                    Wait=1;
                    
                    /*********************************************************************************************/
                    $display("Not Found in L2 cache ,Extrxacting from main memory");
                    if(main_memory_delay_counter < main_memory_latency)
                    begin
                        hit1=0;
                        hit2=0;
                        main_memory_delay_counter=main_memory_delay_counter+1;
                        Wait=1;
                        is_L2_delay=1;
                    
                    end
                    else
                    begin
                        main_memory_delay_counter=0;
                        is_L2_delay=0;
                        hit1=0;
                        hit2=0;
                        Wait=0;
                        L2_delay_counter=0;
                        main_memory_delay_counter=0;
                        for(L2_mm_check=0;L2_mm_check < no_of_L2_ways;L2_mm_check=L2_mm_check+1)
                        begin
                            if(lru[L2_index][((L2_mm_check+1)*no_of_L2_ways_bits-1)-:no_of_L2_ways_bits] == 0)
                            begin
                                L2_mm_check2=L2_mm_check;
                            
                            end
                        
                        end
                        $display("%D",L2_mm_check2);
                        lru_value=lru[L2_index][((L2_mm_check2+1)*no_of_L2_ways_bits-1)-:no_of_L2_ways_bits];
                        $display("%D",lru_value);
                        for(L2_mm_iterator=0;L2_mm_iterator <no_of_L2_ways;L2_mm_iterator=L2_mm_iterator+1)
                        begin
                            $display("Initial");
                            lru_value_dummy=lru[L2_index][((L2_mm_iterator+1)*no_of_L2_ways_bits-1)-:no_of_L2_ways_bits];
                            $display("%D",lru_value);
                            if(lru_value_dummy > lru_value)
                            begin
                                $display("bigger");
                                lru[L2_index][((L2_mm_iterator+1)*no_of_L2_ways_bits-1)-:no_of_L2_ways_bits]=lru_value_dummy-1;
                                
                            end
                        end
                        lru[L2_index][((L2_mm_check2+1)*no_of_L2_ways_bits-1)-:no_of_L2_ways_bits]=no_of_L2_ways-1;
                        $display("%D",lru[L2_index]);
                        if(L2_valid[L2_index][L2_mm_check2] == 0)
                        begin
                            $display("Initially not present in L2");
                            L2_cache_memory[L2_index][((L2_mm_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size]=main_memory[main_memory_blk_id];
                            $display("%B",L2_cache_memory[L2_index][((L2_mm_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size]);
                            L2_valid[L2_index][L2_mm_check2]=1;
                            $display("%B", L2_valid[L2_index][L2_mm_check2]);
                            L2_tag_array[L2_index][((L2_mm_check2+1)*no_of_L2_tag_bits-1)-:no_of_L2_tag_bits]=L2_tag;
                            $display("%B",L2_tag_array[L2_index][((L2_mm_check2+1)*no_of_L2_tag_bits-1)-:no_of_L2_tag_bits]);
                            if(L1_valid[L1_index]==0)
                            begin
                                $display("Initially not present in L1");
                                L1_cache_memory[L1_index]=main_memory[main_memory_blk_id];
                                $display("%B",L1_cache_memory[L1_index]);
                                L1_valid[L1_index]=1;
                                $display("%B",L1_valid[L1_index]);
                                L1_tag_array[L1_index]=L1_tag;
                                $display("%B",L1_tag_array[L1_index]);
                                output_data=L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size];
                                dummy_hit=0;
                            end
                            else
                            begin
                                 $display("Initially present in L1");
                                 L1_evict_tag=L1_tag_array[L1_index];
                                 $display("%B",L1_evict_tag);
                                 L1_to_L2_tag=L1_evict_tag >>(no_of_L1_tag_bits-no_of_L2_tag_bits);
                                 $display("%B",L1_to_L2_tag);
                                 L1_to_L2_index={L1_evict_tag[no_of_L1_tag_bits-no_of_L2_tag_bits-1:0],L1_index};
                                 $display("%B",L1_to_L2_index);
                                 L1_to_L2_search=0;
                                 for(L1_L2_check=0;L1_L2_check < no_of_L2_ways;L1_L2_check=L1_L2_check+1)
                                 begin
                                    if(L2_valid[L2_index][L1_L2_check] && L2_tag_array[L2_index][((L1_L2_check+1)*no_of_L2_tag_bits-1)-:no_of_L2_tag_bits] == L1_to_L2_tag)
                                    begin
                                        L1_to_L2_search=1;
                                        L1_L2_check2=L1_L2_check;
                                    end
                                 end
                                 if(L1_to_L2_search == 1)
                                 begin
                                    $display("Found L1 eviction in L2");
                                    L2_cache_memory[L1_to_L2_index][((L1_L2_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size-1]=L1_cache_memory[L1_index];
                                    $display("%B",L2_cache_memory[L1_to_L2_index][((L1_L2_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size-1]);
                                    L1_cache_memory[L1_index]=L2_cache_memory[L2_index][((L2_mm_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size];
                                    $display("%B",L1_cache_memory[L1_index]);
                                    L1_valid[L1_index]=1;
                                    L1_tag_array[L1_index]=L1_tag;
                                    $display("%B",L1_tag_array[L1_index]);
                                    output_data=L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size];
                                    dummy_hit=0;
                                 end
                                 else
                                 begin
                                    main_memory[{L1_evict_tag,L1_index}]=L1_cache_memory[L1_index];
                                    L1_cache_memory[L1_index]=L2_cache_memory[L2_index][((L2_mm_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size];
                                    $display("%B",L1_cache_memory[L1_index]);
                                    L1_valid[L1_index]=1;
                                    L1_tag_array[L1_index]=L1_tag;
                                    $display("%B",L1_tag_array[L1_index]);
                                    output_data=L1_cache_memory[L1_index][(offset+1)*byte_size-1-:byte_size];
                                    dummy_hit=0;
                                 end
                            end
                        end
                        /********************************************************************************/
                        else
                        begin
                            $display("Intially valid data present in L2");
                            L2_evict_tag=L2_tag_array[L2_index][((L2_mm_check2+1)*no_of_L2_tag_bits-1)-:no_of_L2_tag_bits];
                            main_memory[{L2_evict_tag,L2_index}]=L2_cache_memory[L2_index][((L2_mm_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size];
                            
                            L2_cache_memory[L2_index][((L2_mm_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size]=main_memory[main_memory_blk_id];
                            L2_valid[L2_index][L2_mm_check2]=1;
                            L2_tag_array[L2_index][((L2_mm_check2+1)*no_of_L2_tag_bits-1)-:no_of_L2_tag_bits]=L2_tag;
                            
                            if(L1_valid[L1_index] == 0)
                            begin
                                L1_cache_memory[L1_index]=L2_cache_memory[L2_index][((L2_mm_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size];
                                L1_valid[L1_index]=1;
                                L1_tag_array[L1_index]=L1_tag;
                                output_data=L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size];
                                dummy_hit=0;
                            end
                            else
                            begin
                                L1_evict_tag3=L1_tag_array[L1_index];
                                L1_to_L2_tag3=L1_evict_tag3 >>(no_of_L1_tag_bits-no_of_L2_tag_bits);
                                L1_to_L2_index3={L1_evict_tag3[(no_of_L1_tag_bits-no_of_L2_tag_bits)-1:0],L1_index};
                                L1_to_L2_search3=0;
                                for(L1_L2_checkb=0;L1_L2_checkb < no_of_L2_ways;L1_L2_checkb=L1_L2_checkb+1)
                                begin
                                    if(L2_valid[L1_to_L2_index3][L1_L2_checkb]&&L2_tag_array[L1_to_L2_index3][((L1_L2_checkb+1)*no_of_L2_tag_bits-1)-:no_of_L2_tag_bits] == L1_to_L2_tag3)
                                    begin
                                        L1_to_L2_search3=1;
                                        L1_L2_check2b=L1_L2_checkb;
                                    end
                                end
                                if(L1_to_L2_search3 == 1)
                                begin
                                    L2_cache_memory[L1_to_L2_index3][((L1_L2_check2b+1)*L1_block_bit_size-1)-:L1_block_bit_size]=L1_cache_memory[L1_index];
                                    L1_cache_memory[L1_index]=L2_cache_memory[L2_index][((L2_mm_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size];
                                    L1_valid[L1_index]=1;
                                    L1_tag_array[L1_index]=L1_tag;
                                    output_data=L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size];
                                    dummy_hit=0;
                                end
                                else
                                begin
                                    main_memory[{L1_evict_tag3,L1_index}]=L1_cache_memory[L1_index];
                                    L1_cache_memory[L1_index]=L2_cache_memory[L2_index][((L2_mm_check2+1)*L1_block_bit_size-1)-:L1_block_bit_size];
                                    L1_valid[L1_index]=1;
                                    L1_tag_array[L1_index]=L1_tag;
                                    output_data=L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size];
                                    dummy_hit=0;
                               end
                            end
                         end
                      end
                   end
                 end
               end
             end
        else  //Write operation
        begin
            output_data=0;
            if(L1_valid[L1_index] && L1_tag_array[L1_index] == L1_tag)
            begin
                $display("Found in L1 cache");
                L1_cache_memory[L1_index][((offset+1)*byte_size-1)-:byte_size]=stored_data;
                Wait=0;
                hit1=1;
                hit2=0;
                    
           
            end
            
            else
            begin
                if((L2_delay_counter_w < L2_latency) && is_L2_delay_w == 0)
                begin
                    L2_delay_counter_w=L2_delay_counter_w +1;
                    Wait=1;
                    hit1=0;
                    hit2=0;                  
                
                end
                else
                begin
                    L2_delay_counter_w=0;
                    dummy_hit_w=0;
                    hit1=0;
                    hit2=0;
                    for(L2_checka=0 ; L2_checka < no_of_L2_ways;L2_checka=L2_checka+1)
                    begin
                        if(L2_valid[L2_index][L2_checka] && L2_tag_array[L2_index][((L2_checka+1)*no_of_L2_tag_bits-1)-:no_of_L2_tag_bits]==L2_tag)
                        begin
                            dummy_hit_w=1;
                            hit2=1;
                            hit1=0;
                            Wait=0;
                            L2_cache_memory[L2_index][(L2_checka*L1_block_bit_size+(offset+1)*byte_size-1)-:byte_size]=stored_data;
                            
                        end
                    
                    end
                    if(dummy_hit_w == 0)
                    begin
                        hit1=0;
                        hit2=0;
                        if(main_memory_delay_counter_w < main_memory_latency)
                        begin
                            main_memory_delay_counter_w=main_memory_delay_counter_w+1;
                            hit1=0;
                            hit2=0;
                            Wait=1;
                            is_L2_delay_w=1;
                        
                        end
                        else
                        begin
                            main_memory_delay_counter_w=0;
                            hit1=0;
                            hit2=0;
                            Wait=0;     
                            is_L2_delay_w=0;    
                            main_memory[main_memory_blk_id][((offset+1)*byte_size-1)-:byte_size]=stored_data;                                             
                        end
                      end
                    end
                  end 
                end
              end
endmodule
