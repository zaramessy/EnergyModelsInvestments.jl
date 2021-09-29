"""
    has_capacity(i)

Check if node i should be used for capacity calculations, i.e.
    * is not Availability
    * has capacity

    TODO: Move to EMB?
"""
function testdata()
    data = EMB.read_data("")
end

function has_capacity(i)
    ~isa(i, EMB.Availability) && 
    (
        hasproperty(i, :Cap) ||
        (hasproperty(i, :Rate_cap) && hasproperty(i, :Stor_cap))
    )
end

function has_stor_capacity(i)
    ~isa(i, EMB.Availability) && 
    (
        (hasproperty(i, :Rate_cap) && hasproperty(i, :Stor_cap))
    )
end

function has_investment(i)
    ~isa(i, EMB.Availability) && 
    (
        hasproperty(i, :Data) && (
            haskey(i.Data,"InvestmentModels") &&
            (
                hasproperty(i.Data["InvestmentModels"], :Capex_Cap) ||
                hasproperty(i.Data["InvestmentModels"], :Cap_max_inst) ||
                hasproperty(i.Data["InvestmentModels"], :Cap_max_add) ||
                hasproperty(i.Data["InvestmentModels"], :Cap_min_add)
            )
        )
    )
end

function has_storage_investment(i)
    ~isa(i, EMB.Availability) && 
    (
        hasproperty(i, :Data) && (
            haskey(i.Data,"InvestmentModels") &&
            (
                hasproperty(i.Data["InvestmentModels"], :Capex_stor) ||
                hasproperty(i.Data["InvestmentModels"], :Stor_max_inst) ||
                hasproperty(i.Data["InvestmentModels"], :Stor_max_add) ||
                hasproperty(i.Data["InvestmentModels"], :Stor_min_add)
            )
        )
    )
end
