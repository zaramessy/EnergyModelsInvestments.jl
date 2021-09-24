const GEO = Geography

function GEO.read_data(modeltype::InvestmentModel)
    @debug "Read data"
    @info "Hard coded dummy model for now (Investment Model)"

    𝒫₀, 𝒫ᵉᵐ₀, products = GEO.get_resources()

    #
    area_ids = [1, 2, 3, 4]
    d_scale = Dict(1=>3.0, 2=>1.5, 3=>1.0, 4=>0.5)
    mc_scale = Dict(1=>2.0, 2=>2.0, 3=>1.5, 4=>0.5)


    # Create identical areas with index according to input array
    an = Dict()
    transmission = []
    nodes = []
    links = []
    for a_id in area_ids
        n, l = GEO.get_sub_system_data(a_id, 𝒫₀, 𝒫ᵉᵐ₀, products; mc_scale = mc_scale[a_id], d_scale = d_scale[a_id], modeltype=modeltype)
        append!(nodes, n)
        append!(links, l)

        # Add area node for each subsystem
        an[a_id] = n[1]
    end

    areas = [GEO.Area(1, "Oslo", 10.751, 59.921, an[1]),
            GEO.Area(2, "Bergen", 5.334, 60.389, an[2]),
            GEO.Area(3, "Trondheim", 10.398, 63.4366, an[3]),
            GEO.Area(4, "Tromsø", 18.953, 69.669, an[4])]

    NG = products[2]
    Power = products[3]

    OverheadLine_50MW = GEO.RefStatic("PowerLine_50", Power, 50.0, 0.05)#, EMB.Linear)
    LNG_Ship_100MW = GEO.RefDynamic("LNG_100", NG, 100.0, 0.05)#, EMB.Linear)

    # Create transmission between areas
    transmission = [GEO.Transmission(areas[1], areas[2], [OverheadLine_50MW],[Dict("InvestmentModels"=> TransInvData(Capex_trans=FixedProfile(1000), Trans_max_inst=FixedProfile(50), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(0), Inv_mode=DiscreteInvestment()))]),
                    GEO.Transmission(areas[1], areas[3], [OverheadLine_50MW],[Dict("InvestmentModels"=> TransInvData(Capex_trans=FixedProfile(1000), Trans_max_inst=FixedProfile(100), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(10), Inv_mode=SemiContinuousInvestment(), Trans_start=0))]),
                    GEO.Transmission(areas[2], areas[3], [OverheadLine_50MW],[Dict("InvestmentModels"=> TransInvData(Capex_trans=FixedProfile(1000), Trans_max_inst=FixedProfile(50), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(5), Inv_mode=IntegerInvestment(), Trans_increment=FixedProfile(6), Trans_start=20))]),
                    GEO.Transmission(areas[3], areas[4], [OverheadLine_50MW],[Dict("InvestmentModels"=> TransInvData(Capex_trans=FixedProfile(1000), Trans_max_inst=FixedProfile(50), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(1), Inv_mode=ContinuousInvestment(), Trans_start=0))]),
                    GEO.Transmission(areas[4], areas[2], [LNG_Ship_100MW],[Dict(""=> EMB.EmptyData())])]

    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    # WIP data structure
    data = Dict(
                :areas => Array{GEO.Area}(areas),
                :transmission => Array{GEO.Transmission}(transmission),
                :nodes => Array{EMB.Node}(nodes),
                :links => Array{EMB.Link}(links),
                :products => products,
                :T => T
                )
    return data
end

function GEO.get_sub_system_data(i,𝒫₀, 𝒫ᵉᵐ₀, products; mc_scale::Float64=1.0, d_scale::Float64=1.0, modeltype::InvestmentModel)
    
    NG, Coal, Power, CO2 = products

    demand = [20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
              20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
              20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
              20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]
    demand *= d_scale

    j=(i-1)*100
    nodes = [
            GEO.GeoAvailability(j+1, 𝒫₀, 𝒫₀),
            EMB.RefSink(j+2, DynamicProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]),
                    Dict(:surplus => 0, :deficit => 1e6), Dict(Power => 1), 𝒫ᵉᵐ₀),
            EMB.RefSource(j+3, FixedProfile(30), FixedProfile(30*mc_scale), FixedProfile(100), Dict(NG => 1), 𝒫ᵉᵐ₀,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(1000),max_inst_cap=FixedProfile(200),max_add=FixedProfile(200),min_add=FixedProfile(10),inv_mode=ContinuousInvestment(), cap_increment=FixedProfile(5), start_cap=15))),  
            EMB.RefSource(j+4, FixedProfile(9), FixedProfile(9*mc_scale), FixedProfile(100), Dict(Coal => 1), 𝒫ᵉᵐ₀,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(1000),max_inst_cap=FixedProfile(200),max_add=FixedProfile(200),min_add=FixedProfile(0),inv_mode=ContinuousInvestment()))),  
            EMB.RefGeneration(j+5, FixedProfile(0), FixedProfile(5.5*mc_scale), FixedProfile(100), Dict(NG => 2), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0.9,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(600),max_inst_cap=FixedProfile(25),max_add=FixedProfile(25),min_add=FixedProfile(0),inv_mode=ContinuousInvestment()))),  
            EMB.RefGeneration(j+6, FixedProfile(0), FixedProfile(6*mc_scale), FixedProfile(100),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(800),max_inst_cap=FixedProfile(25),max_add=FixedProfile(25),min_add=FixedProfile(0),inv_mode=ContinuousInvestment()))),  
            EMB.RefStorage(j+7, FixedProfile(0), FixedProfile(0), FixedProfile(9.1*mc_scale), FixedProfile(100),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("InvestmentModels" => extra_inv_data_storage(capex=FixedProfile(0),max_inst_cap=FixedProfile(600),max_add=FixedProfile(600),min_add=FixedProfile(0),capex_stor=FixedProfile(500),max_inst_stor=FixedProfile(600),max_add_stor=FixedProfile(600),min_add_stor=FixedProfile(0),inv_mode=ContinuousInvestment()))),
            EMB.RefGeneration(j+8, FixedProfile(2), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(0),max_inst_cap=FixedProfile(25),max_add=FixedProfile(2),min_add=FixedProfile(2),inv_mode=ContinuousInvestment()))),  
            EMB.RefStorage(j+9, FixedProfile(3), FixedProfile(5), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("InvestmentModels" => extra_inv_data_storage(capex=FixedProfile(0),max_inst_cap=FixedProfile(30),max_add=FixedProfile(3),min_add=FixedProfile(3),capex_stor=FixedProfile(0),max_inst_stor=FixedProfile(50),max_add_stor=FixedProfile(5),min_add_stor=FixedProfile(5),inv_mode=ContinuousInvestment()))),
            EMB.RefGeneration(j+10, FixedProfile(0), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(10000),max_inst_cap=FixedProfile(10000),max_add=FixedProfile(10000),min_add=FixedProfile(0),inv_mode=ContinuousInvestment()))),  
                ]

    links = [
            EMB.Direct(j*10+15,nodes[1],nodes[5],EMB.Linear())
            EMB.Direct(j*10+16,nodes[1],nodes[6],EMB.Linear())
            EMB.Direct(j*10+17,nodes[1],nodes[7],EMB.Linear())
            EMB.Direct(j*10+18,nodes[1],nodes[8],EMB.Linear())
            EMB.Direct(j*10+19,nodes[1],nodes[9],EMB.Linear())
            EMB.Direct(j*10+110,nodes[1],nodes[10],EMB.Linear())
            EMB.Direct(j*10+12,nodes[1],nodes[2],EMB.Linear())
            EMB.Direct(j*10+31,nodes[3],nodes[1],EMB.Linear())
            EMB.Direct(j*10+41,nodes[4],nodes[1],EMB.Linear())
            EMB.Direct(j*10+51,nodes[5],nodes[1],EMB.Linear())
            EMB.Direct(j*10+61,nodes[6],nodes[1],EMB.Linear())
            EMB.Direct(j*10+71,nodes[7],nodes[1],EMB.Linear())
            EMB.Direct(j*10+81,nodes[8],nodes[1],EMB.Linear())
            EMB.Direct(j*10+91,nodes[9],nodes[1],EMB.Linear())
            EMB.Direct(j*10+101,nodes[10],nodes[1],EMB.Linear())
                    ]
    return nodes, links
end