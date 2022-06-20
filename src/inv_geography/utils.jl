const GEO = Geography

function has_trans_investment(i)
    """For a given transmission, checks that it contains extra data
    (i.Data : list containing the extra data of the different corridor modes) and that 
    at leat one corridor mode has investment data defined.
     """
    isa(i, GEO.Transmission) && 
    (
        hasproperty(i, :Data) && haskey(i.Data, "InvestmentModels") && isempty(keys(i.Data["InvestmentModels"])) && any(x-> x != EMB.EmptyData(), values(i.Data["InvestmentModels"]))
    )
end

function has_cm_investment(cm,l)
    isa(cm, GEO.TransmissionMode) &&
    isa(l, GEO.Transmission) &&
    cm ∈ l.Modes  &&
    haskey(l.Data, "InvestmentModels") &&
    (
        hasproperty(l.Data["InvestmentModels"][cm], :Trans_max_inst) ||
        hasproperty(l.Data["InvestmentModels"][cm], :Capex_trans) ||
        hasproperty(l.Data["InvestmentModels"][cm], :Trans_max_add) ||
        hasproperty(l.Data["InvestmentModels"][cm], :Trans_min_add)
    )
end

function corridor_modes_with_inv(l)
    if "InvestmentModels" ∈ keys(l.Data)
        return [m for m ∈ l.Modes if (!=(l.Data["InvestmentModels"][m], EMB.EmptyData))]
    else
        return []
    end
end