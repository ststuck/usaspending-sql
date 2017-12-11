create materialized view fpds_matview_temp as
(
select
    'cont_aw_' ||
        coalesce(tf.agency_id,'-none-') || '_' ||
        coalesce(tf.referenced_idv_agency_iden,'-none-') || '_' ||
        coalesce(tf.piid,'-none-') || '_' ||
        coalesce(tf.parent_award_id,'-none-') as generated_unique_award_id,
    tf.contract_award_type as type,
    tf.contract_award_type_desc as type_description,
    ac.type_name as category,
    tf.agency_id,
    tf.referenced_idv_agency_iden,
    tf.piid as piid,
    tf.parent_award_id as parent_award_piid,
    null::text as fain,
    null::text as uri,
    uniq_award.total_obligation as total_obligation,
    null::float as total_outlay,
    awarding_agency.agency_id as awarding_agency_id,
    tf.awarding_sub_tier_agency_c as awarding_sub_tier_agency_c,
    funding_agency.agency_id as funding_agency_id,
    'DBR'::text as data_source,
    uniq_award.signed_date as date_signed,
    tf.award_description as description,
    uniq_award.period_of_performance_start_date as period_of_performance_start_date,
    uniq_award.period_of_performance_current_end_date as period_of_performance_current_end_date,
    null::float as potential_total_value_of_award,
    uniq_award.base_and_all_options_value as base_and_all_options_value,
    tf.last_modified as last_modified_date, 
    uniq_award.certified_date as certified_date,
    tf.transaction_id as latest_transaction_id,
    'cont_tx_' || tf.detached_award_proc_unique as latest_transaction_unique,
    0 as total_subaward_amount,
    0 as subaward_count,
    
    -- recipient data
    tf.awardee_or_recipient_uniqu as recipient_unique_id, -- DUNS
    tf.awardee_or_recipient_legal as recipient_name,

    -- executive compensation data
    exec_comp.officer_1_name as officer_1_name,
    exec_comp.officer_1_amount as officer_1_amount,
    exec_comp.officer_2_name as officer_2_name,
    exec_comp.officer_2_amount as officer_2_amount,
    exec_comp.officer_3_name as officer_3_name,
    exec_comp.officer_3_amount as officer_3_amount,
    exec_comp.officer_4_name as officer_4_name,
    exec_comp.officer_4_amount as officer_4_amount,
    exec_comp.officer_5_name as officer_5_name,
    exec_comp.officer_5_amount as officer_5_amount,

    -- business categories
    tf.legal_entity_address_line1 as recipient_location_address_line1,
    tf.legal_entity_address_line2 as recipient_location_address_line2,
    tf.legal_entity_address_line3 as recipient_location_address_line3,
    
    -- foreign province
    null::text as recipient_location_foreign_province,
    
    -- country
    tf.legal_entity_country_code as recipient_location_country_code,
    tf.legal_entity_country_name as recipient_location_country_name,
    
    -- state
    tf.legal_entity_state_code as recipient_location_state_code,
    tf.legal_entity_state_descrip as recipient_location_state_name,
    
    -- county (NONE FOR FPDS)
    null::text as recipient_location_county_code,
    null::text as recipient_location_county_name,
    
    -- city
    tf.legal_entity_city_name as recipient_location_city_name,
    
    -- zip
    (substring(tf.legal_entity_zip4 from '^(\d{5})\-?(\d{4})?$')) as recipient_location_zip5,
    
    -- congressional disctrict
    tf.legal_entity_congressional as recipient_location_congressional_code,
    
    -- ppop data
    
    -- foreign
    null::text as pop_foreign_province,
    
    -- country
    tf.place_of_perform_country_c as pop_country_code,
    tf.place_of_perf_country_desc as pop_country_name,
    
    -- state
    tf.place_of_performance_state as pop_state_code,
    tf.place_of_perfor_state_desc as pop_state_name,
    
    -- county
    null::text as pop_county_code,
    tf.place_of_perform_county_na as pop_county_name,
    
    -- city
    tf.place_of_perform_city_name as pop_city_name,
    
    -- zip
    (substring(tf.place_of_performance_zip4a from '^(\d{5})\-?(\d{4})?$')) as pop_zip5,
    tf.place_of_performance_zip4a as pop_zip4,
    
    -- congressional disctrict
    tf.place_of_performance_congr as pop_congressional_code
from
    transaction_fpds as tf -- latest transaction
    inner join
    (
        select
            distinct on (transaction_fpds.piid, transaction_fpds.parent_award_id, transaction_fpds.agency_id, transaction_fpds.referenced_idv_agency_iden)
            transaction_fpds.piid,
            transaction_fpds.parent_award_id,
            transaction_fpds.agency_id,
            transaction_fpds.referenced_idv_agency_iden,
            transaction_fpds.action_date,
            transaction_fpds.transaction_number,
            transaction_fpds.award_modification_amendme,
            transaction_fpds.detached_award_proc_unique,
            count(transaction_fpds.piid) over w as sumpiid,
            max(transaction_fpds.action_date) over w as certified_date,
            min(transaction_fpds.action_date) over w as signed_date,
            min(transaction_fpds.period_of_performance_star::date) over w as period_of_performance_start_date,
            max(transaction_fpds.period_of_performance_curr::date) over w as period_of_performance_current_end_date,
            sum(coalesce(transaction_fpds.base_and_all_options_value::double precision, 0::double precision)) over w as base_and_all_options_value,
            sum(coalesce(transaction_fpds.federal_action_obligation::double precision, 0::double precision)) over w as total_obligation
        from transaction_fpds
        window w as (partition by transaction_fpds.piid, transaction_fpds.parent_award_id, transaction_fpds.agency_id, transaction_fpds.referenced_idv_agency_iden)
        order by 
            transaction_fpds.piid, 
            transaction_fpds.parent_award_id, 
            transaction_fpds.agency_id, 
            transaction_fpds.referenced_idv_agency_iden, 
            transaction_fpds.action_date desc, 
            transaction_fpds.award_modification_amendme desc, 
            transaction_fpds.transaction_number desc
    ) as uniq_award on uniq_award.detached_award_proc_unique = tf.detached_award_proc_unique
    inner join
    award_category as ac on ac.type_code = tf.contract_award_type
    inner join
    agency_lookup as awarding_agency on awarding_agency.subtier_code = tf.awarding_sub_tier_agency_c 
    left outer join
    agency_lookup as funding_agency on funding_agency.subtier_code = tf.funding_sub_tier_agency_co
    left outer join
    exec_comp_lookup as exec_comp on exec_comp.duns = tf.awardee_or_recipient_uniqu
);