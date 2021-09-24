"""
    objective(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create objective function overloading the default from EMB for InvestmentModel.

Maximize Net Present Value from revenues, investments (CAPEX) and operations (OPEX) 

## TODO: 
# * consider passing expression around for updating
# * consider reading objective and adding terms/coefficients (from model object `m`)

"""
function EMB.objective(m, 𝒩, 𝒯, 𝒫, modeltype::InvestmentModel)#, sense=Max)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩ᶜᵃᵖ = (i for i ∈ 𝒩 if has_capacity(i))
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩 if has_investment(i))
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)
    r = modeltype.r     # Discount rate

    capexunit = 1 # TODO: Fix scaling if operational units are different form CAPEX

    obj = JuMP.AffExpr()

    haskey(m, :revenue) && (obj += sum(obj_weight(r, 𝒯, t_inv, t) * m[:revenue][i, t] / capexunit for i ∈ 𝒩ᶜᵃᵖ, t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ 𝒯))
    haskey(m, :opex_var) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:opex_var][i, t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    haskey(m, :opex_fixed) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:opex_fixed][i, t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    haskey(m, :capex_cap) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:capex_cap][i,t]  for i ∈ 𝒩ᴵⁿᵛ, t ∈  𝒯ᴵⁿᵛ))
    if haskey(m, :capex_stor) && isempty(𝒩ˢᵗᵒʳ) == false
        obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:capex_stor][i,t]  for i ∈ 𝒩ˢᵗᵒʳ, t ∈  𝒯ᴵⁿᵛ) #capex of the capacity part ofthe storage (by opposition to the power part)
    end
    em_price = modeltype.case.emissions_price
    obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:emissions_strategic][t, p_em] * em_price[p_em][t] for p_em ∈ 𝒫ᵉᵐ, t ∈ 𝒯ᴵⁿᵛ)
    
    # TODO: Maintentance cost
    # TODO: Residual value

    @objective(m, Max, obj)
end


function EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::InvestmentModel)
    
    𝒩ⁿᵒᵗ = EMB.node_not_av(𝒩)
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m,capex_cap[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m,capex_stor[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)

end

"""
    variables_capacity(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.
"""
function EMB.variables_capacity(m, 𝒩, 𝒯, modeltype::InvestmentModel)
    @debug "Create investment variables"


    @variable(m, cap_use[𝒩, 𝒯] >= 0) # Linking variables used in EMB

    # Add investment variables for each strategic period:
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @variable(m, cap_invest_b[𝒩, 𝒯ᴵⁿᵛ])
    @variable(m, cap_remove_b[𝒩, 𝒯ᴵⁿᵛ])
    @variable(m, cap_current[𝒩, 𝒯ᴵⁿᵛ] >= 0)     # Installed capacity
    @variable(m, cap_add[𝒩, 𝒯ᴵⁿᵛ]  >= 0)        # Add capacity
    @variable(m, cap_rem[𝒩, 𝒯ᴵⁿᵛ]  >= 0)        # Remove capacity
    @variable(m, cap_inst[𝒩, 𝒯]     >= 0)       # Max capacity

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_capacity(m, 𝒩, 𝒯)
end

"""
    variables_storage(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.
"""
function EMB.variables_storage(m, 𝒩, 𝒯, modeltype::InvestmentModel)

    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)

    @variable(m, stor_level[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add storage specific investment variables for each strategic period:
    @variable(m, stor_cap_invest_b[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_cap_remove_b[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_cap[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Installed capacity
    @variable(m, stor_cap_add[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Add capacity
    @variable(m, stor_cap_rem[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Remove capacity
    @variable(m, stor_cap_inst[𝒩ˢᵗᵒʳ, 𝒯]    >= 0)    # Max storage capacity

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_storage(m, 𝒩ˢᵗᵒʳ, 𝒯)
end

"""
    constraints_capacity(m, 𝒩, 𝒯)
Set capacity-related constraints for nodes `𝒩` for investment time structure `𝒯`:
* bounds
* binary for DiscreteInvestment
* link capacity variables

"""
function constraints_capacity(m, 𝒩, 𝒯)
    

    𝒩ᶜᵃᵖ = (i for i ∈ 𝒩 if has_capacity(i))
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩 if has_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    #constraints capex
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:capex_cap][n,t_inv] == n.Data["InvestmentModels"].Capex_Cap[t_inv] * m[:cap_add][n, t_inv])
    end 
    
    
    # TODO, constraint for setting the minimum investment capacity
    # using binaries/semi continuous variables

    # Set investment properties based on investment mode of node n
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:cap_invest_b][n, t_inv])  
    end

    # Link capacity usage to installed capacity 
    for n ∈ 𝒩ᶜᵃᵖ
        if n ∈ 𝒩ᴵⁿᵛ
            for t_inv in 𝒯ᴵⁿᵛ, t in t_inv
                @constraint(m, m[:cap_inst][n, t] == m[:cap_current][n,t_inv])
            end
        else
            for t in 𝒯
                @constraint(m, m[:cap_inst][n, t] == n.Cap[t])
            end
        end
    end

    for n ∈ 𝒩ᶜᵃᵖ, t ∈ 𝒯
        @constraint(m, m[:cap_use][n, t] <= m[:cap_inst][n, t]) # sum cap_add/cap_rem
    end

    # Capacity updating
    for n ∈ 𝒩ᴵⁿᵛ
        for t_inv ∈ 𝒯ᴵⁿᵛ
            start_cap = get_start_cap(n,t_inv, n.Data["InvestmentModels"].Cap_start)
            @constraint(m, m[:cap_current][n, t_inv] <= n.Data["InvestmentModels"].Cap_max_inst[t_inv])
            @constraint(m, m[:cap_current][n, t_inv] ==
                (TS.isfirst(t_inv) ? start_cap : m[:cap_current][n, previous(t_inv,𝒯)])
                + m[:cap_add][n, t_inv] 
                - (TS.isfirst(t_inv) ? 0 : m[:cap_rem][n, previous(t_inv,𝒯)]))
        end
        set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)
    end
end

"""
    constraints_storage(m, 𝒩ˢᵗᵒʳ, 𝒯)
Set storage-related constraints for nodes `𝒩ˢᵗᵒʳ` for investment time structure `𝒯`:
* bounds
* binary for DiscreteInvestment
* link storage variables

"""
function constraints_storage(m, 𝒩ˢᵗᵒʳ, 𝒯)
    
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩ˢᵗᵒʳ if has_storage_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraints capex
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:capex_stor][n,t_inv] == n.Data["InvestmentModels"].Capex_stor[t_inv] * m[:stor_cap_add][n, t_inv])
    end 
    

    # Set investment properties based on investment mode of node n
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:stor_cap_invest_b][n, t_inv])  
    end

    # Link capacity usage to installed capacity 
    for n ∈ 𝒩ˢᵗᵒʳ
        if n ∈ 𝒩ᴵⁿᵛ
            for t_inv in 𝒯ᴵⁿᵛ, t in t_inv
                @constraint(m, m[:stor_cap_inst][n, t] == m[:stor_cap][n,t_inv])
            end
        else
            for t in 𝒯
                @constraint(m, m[:stor_cap_inst][n, t] == n.Stor_cap[t])
            end
        end
    end

    # Capacity updating
    for n ∈ 𝒩ᴵⁿᵛ
        for t_inv ∈ 𝒯ᴵⁿᵛ
            start_cap = get_start_cap_storage(n,t_inv,n.Data["InvestmentModels"].Stor_start_cap)
            @constraint(m, m[:stor_cap][n, t_inv] <= n.Data["InvestmentModels"].Stor_max_inst[t_inv])
            @constraint(m, m[:stor_cap][n, t_inv] == 
                (TS.isfirst(t_inv) ? start_cap : m[:stor_cap][n, previous(t_inv,𝒯)]) 
                + m[:stor_cap_add][n, t_inv]
                - (TS.isfirst(t_inv) ? 0 : m[:stor_cap_rem][n, previous(t_inv,𝒯)]))
        end
        set_storage_installation(m, n, 𝒯ᴵⁿᵛ)
    end
end

"""
    set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to capacity installation depending on investment mode of node `n`
"""
set_capacity_installation(m, n, 𝒯ᴵⁿᵛ) = set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode(n))
function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_add][n, t_inv] <= n.Data["InvestmentModels"].Cap_max_add[t_inv])
        @constraint(m, m[:cap_add][n, t_inv] >= n.Data["InvestmentModels"].Cap_min_add[t_inv])
        @constraint(m, m[:cap_rem][n, t_inv] == 0)
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_current][n, t_inv] == n.capacity[t_inv] * m[:cap_invest_b][n, t_inv]) 
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::IntegerInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:cap_remove_b][n,t_inv])
        @constraint(m, m[:cap_add][n, t_inv] == n.Data["InvestmentModels"].Cap_increment[t_inv] * m[:cap_invest_b][n, t_inv])
        @constraint(m, m[:cap_rem][n, t_inv] == n.Data["InvestmentModels"].Cap_increment[t_inv] * m[:cap_remove_b][n, t_inv])
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::SemiContinuousInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_add][n, t_inv] <= n.Data["InvestmentModels"].Cap_max_add[t_inv] )
        @constraint(m, m[:cap_add][n, t_inv] >= n.Data["InvestmentModels"].Cap_min_add[t_inv] * m[:cap_invest_b][n, t_inv]) 
        @constraint(m, m[:cap_rem][n, t_inv] == 0)
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:capacity][n, t_inv] == n.capacity[t_inv] * m[:invest][n, t_inv])
    end
end

function get_start_cap(n, t, stcap)
    return stcap
end

function get_start_cap(n::EMB.Node, t, ::Nothing)
    return TimeStructures.getindex(n.capacity,t)
end

"""
    set_storage_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to storage installation depending on investment mode of node `n`
"""
set_storage_installation(m, n, 𝒯ᴵⁿᵛ) = set_storage_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode(n))
set_storage_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode) = empty
function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, investmentmode)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap_add][n, t_inv] <= n.Data["InvestmentModels"].Stor_max_add[t_inv])
        @constraint(m, m[:stor_cap_add][n, t_inv] >= n.Data["InvestmentModels"].Stor_min_add[t_inv])
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap][n, t_inv] <= n.cap_stor[t_inv] * m[:stor_cap_invest_b][n, t_inv])
    end
end

function set_storage_installation(m, n, 𝒯ᴵⁿᵛ, ::IntegerInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:stor_cap_remove_b][n,t_inv])
        @constraint(m, m[:add_stor][n, t_inv] == n.data["InvestmentModels"].cap_increment_stor[t_inv] * m[:stor_cap_invest_b][n, t_inv])
        @constraint(m, m[:rem_stor][n, t_inv] == n.data["InvestmentModels"].cap_increment_stor[t_inv] * m[:stor_cap_remove_b][n, t_inv])
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::SemiContinuousInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:add_stor][n, t_inv] <= n.data["InvestmentModels"].max_add_stor[t_inv] )
        @constraint(m, m[:add_stor][n, t_inv] >= n.data["InvestmentModels"].min_add_stor[t_inv] * m[:invest_stor][n, t_inv]) 
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_stor][n, t_inv] == n.cap_stor * m[:invest_stor][n, t_inv])
    end
end

function get_start_cap_storage(n, t, stcap)
    return stcap
end

function get_start_cap_storage(n, t, ::Nothing)
    return TimeStructures.getindex(n.cap_storage,t)
end

"""
    set_investment_properties(n, var)
Set investment properties for variable `var` for node `n`, e.g. set to binary for DiscreteInvestment, 
bounds etc
"""
set_investment_properties(n, var) = set_investment_properties(n, var, investmentmode(n))
function set_investment_properties(n, var, mode)
    set_lower_bound(var, 0)
end

function set_investment_properties(n, var, ::DiscreteInvestment)
    JuMP.set_binary(var)
end

function set_investment_properties(n, var, ::SemiContinuousInvestment)
    JuMP.set_binary(var)
end
    
"""
    set_investment_properties(n, var, ::IndividualInvestment)
Look up if binary investment from n and dispatch on that
"""
function set_investment_properties(n, var, ::IndividualInvestment)
    dispatch_mode = n.data["InvestmentModels"].inv_mode
    set_investment_properties(n, var, dispatch_mode)
end

function set_investment_properties(n, var, ::FixedInvestment) # TO DO
    JuMP.fix(var, 1)
end

function set_investment_properties(n, var, ::IntegerInvestment) # TO DO
    JuMP.set_integer(var)
    JuMP.set_lower_bound(var,0)
end
