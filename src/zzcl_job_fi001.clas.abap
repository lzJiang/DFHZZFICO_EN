CLASS zzcl_job_fi001 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object .
    INTERFACES if_apj_rt_exec_object .
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zzcl_job_fi001 IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    DATA  et_parameters TYPE if_apj_rt_exec_object=>tt_templ_val  .

    et_parameters = VALUE #(
        ( selname = 'PROJECT'
          kind = if_apj_dt_exec_object=>select_option
          sign = 'I'
          option = 'EQ'
          low = 'DFH-2024-YF-002' )
         ( selname = 'PROCESS'
          kind = if_apj_dt_exec_object=>select_option
          sign = 'I'
          option = 'EQ'
          low = '1' )
      ).
    TRY.
        if_apj_rt_exec_object~execute( it_parameters = et_parameters ).
      CATCH cx_root INTO DATA(job_scheduling_exception).
              IF 1 = 1.
          ENDIF.
    ENDTRY.
  ENDMETHOD.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
       ( selname        = 'PROJECT'
         kind           = if_apj_dt_exec_object=>select_option
         datatype       = 'C'
         length         = 24
         param_text     = '项目标识'
         changeable_ind = abap_true )
      ( selname        = 'PROCESS'
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'C'
        length         = 1
        param_text     = 'JOB处理方式(1前台;2后台)'
        changeable_ind = abap_true
        mandatory_ind  = abap_true  )
       ).


  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.

    DATA:s_project  TYPE RANGE OF i_enterpriseproject-project .
    DATA:lv_process TYPE ze_job_proc.
    DATA:r_tmstmp  TYPE RANGE OF i_enterpriseproject-projectlastchangeddatetime,
         lv_bstamp TYPE i_enterpriseproject-projectlastchangeddatetime,
         lv_estamp TYPE i_enterpriseproject-projectlastchangeddatetime.
    DATA:lt_ztfi004 TYPE TABLE OF zztfi_0004,
         ls_ztfi004 TYPE zztfi_0004.

    DATA:lv_oref     TYPE zzefname,
         lt_ptab     TYPE abap_parmbind_tab,
         lv_numb     TYPE zzenumb VALUE 'FI002',
         lv_method   TYPE if_web_http_client=>method,
         lv_req      TYPE string,
         lv_resp     TYPE string,
         lv_msgty    TYPE bapi_mtype,
         lv_msgtx    TYPE bapi_msg,
         lv_text     TYPE string,
         lv_severity TYPE c LENGTH 1..

    LOOP AT it_parameters INTO DATA(l_parameter).
      CASE l_parameter-selname.
        WHEN 'PROJECT'.
          APPEND VALUE #( sign   = l_parameter-sign
                          option = l_parameter-option
                          low    = l_parameter-low
                          high   = l_parameter-high  ) TO s_project.
        WHEN 'METHOD'.
          "lv_method = l_parameter-low.
        WHEN 'PROCESS'.
          lv_process = l_parameter-low.
      ENDCASE.
    ENDLOOP.

    CASE lv_process.
      WHEN '1'.
        SELECT a~project,
               a~projectdescription,
               a~enterpriseprojecttype,
               a~plannedstartdate,
               a~plannedenddate,
               a~processingstatus
          FROM i_enterpriseproject WITH PRIVILEGED ACCESS AS a
         WHERE a~project IN @s_project
          INTO TABLE @DATA(lt_project).
      WHEN '2'.
        "没有参数，默认后台增量推送
        lv_bstamp =  zzcl_comm_tool=>get_last_execute2( 'FI002' ).
        GET TIME STAMP FIELD lv_estamp.
        APPEND  VALUE #( option = 'BT'
                         sign   = 'I'
                         low    = lv_bstamp
                         high   = lv_estamp
                    ) TO r_tmstmp.

        SELECT a~project,
               a~projectdescription,
               a~enterpriseprojecttype,
               a~plannedstartdate,
               a~plannedenddate,
               a~processingstatus
          FROM i_enterpriseproject WITH PRIVILEGED ACCESS AS a
          WHERE a~projectlastchangeddatetime IN @r_tmstmp
          INTO TABLE @lt_project.
    ENDCASE.



    "获取调用类
    SELECT SINGLE zzcname
      FROM zr_vt_rest_conf
     WHERE zznumb = @lv_numb
      INTO @lv_oref.
    CHECK lv_oref IS NOT INITIAL.


    TYPES:BEGIN OF ty_data,
            code            TYPE string,
            name            TYPE string,
            costcentercode  TYPE string,
            budgetstartdate TYPE string,
            budgetenddate   TYPE string,
            enabled         TYPE abap_bool,
            public          TYPE abap_bool,
          END OF ty_data.
    DATA:ls_data TYPE ty_data.
    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.

*&---导入结构JSON MAPPING
    lt_mapping = VALUE #(
         ( abap = 'code'                 json = 'code'                )
         ( abap = 'name'                 json = 'name'                )
         ( abap = 'costCenterCode'       json = 'costCenterCode'      )
         ( abap = 'budgetStartDate'      json = 'budgetStartDate'     )
         ( abap = 'budgetEndDate'        json = 'budgetEndDate'       )
         ( abap = 'enabled'              json = 'enabled'             )
         ( abap = 'public'               json = 'public'              )
         ).

*&--调用实例化接口
    DATA:lo_oref TYPE REF TO object.
    lt_ptab = VALUE #( ( name  = 'IV_NUMB' kind  = cl_abap_objectdescr=>exporting value = REF #( lv_numb ) ) ).



    TRY.
        DATA(l_log) = cl_bali_log=>create_with_header(
             header = cl_bali_header_setter=>create( object = 'ZZ_ALO_API'
                                                     subobject = 'ZZ_ALO_API_SUB' ) ).

        LOOP AT lt_project INTO DATA(ls_project).

          CLEAR:ls_data,lv_req,lv_resp,lv_msgty,lv_msgtx.

          ls_data-code = ls_project-project.
          ls_data-name = ls_project-projectdescription.
          ls_data-costcentercode = ls_project-enterpriseprojecttype.
          CASE ls_data-costcentercode.
            WHEN 'X5'.
              ls_data-costcentercode = 'YFXM'.
            WHEN OTHERS.
              ls_data-costcentercode = 'TYXM'.
          ENDCASE.

          ls_data-budgetstartdate = |{ ls_project-plannedstartdate+0(4) }-{ ls_project-plannedstartdate+4(2) }-{ ls_project-plannedstartdate+6(2) }|.
          ls_data-budgetenddate = |{ ls_project-plannedenddate+0(4) }-{ ls_project-plannedenddate+4(2) }-{ ls_project-plannedenddate+6(2) }|.
          CASE ls_project-processingstatus.
            WHEN '10'.
              ls_data-enabled = abap_true.
            WHEN '20' OR '40' OR '42'.
              ls_data-enabled = abap_false.
          ENDCASE.

          ls_data-public = abap_true.

          "传入数据转JSON
          lv_req = /ui2/cl_json=>serialize(
                data          = ls_data
                name_mappings = lt_mapping ).

          SELECT SINGLE *
            FROM zztfi_0004
           WHERE project = @ls_project-project
            INTO @ls_ztfi004.
          IF sy-subrc = 0.
            lv_method = if_web_http_client=>put.
          ELSE.
            ls_ztfi004-project = ls_project-project.
            lv_method = if_web_http_client=>post.
          ENDIF.

          TRY .
              CREATE OBJECT lo_oref TYPE (lv_oref) PARAMETER-TABLE lt_ptab.
              CALL METHOD lo_oref->('HLYOUT')
                EXPORTING
                  iv_data   = lv_req
                  iv_method = lv_method
                CHANGING
                  ev_resp   = lv_resp
                  ev_msgty  = lv_msgty
                  ev_msgtx  = lv_msgtx.
            CATCH cx_root INTO DATA(lr_root).
              DATA(lv_error) = lr_root->get_longtext( ).
          ENDTRY.

          CASE lv_msgty.
            WHEN 'S'.
              GET TIME STAMP FIELD ls_ztfi004-local_last_changed_at.
              APPEND ls_ztfi004 TO lt_ztfi004.
              lv_severity = if_bali_constants=>c_severity_status.
            WHEN 'E'.
              lv_severity = if_bali_constants=>c_severity_error.
          ENDCASE.

          lv_text = |{ ls_project-project }--| &&
                     |{ lv_msgtx }|.

          l_log->add_item( item = cl_bali_free_text_setter=>create(
            severity = lv_severity
            text = CONV #( lv_text ) ) ).

          FREE lo_oref.
        ENDLOOP.
        IF lt_project IS INITIAL.
          l_log->add_item( item = cl_bali_free_text_setter=>create(
            severity = if_bali_constants=>c_severity_warning
            text = CONV #( |没有可推送数据！| ) ) ).
        ENDIF.

        IF lt_ztfi004 IS NOT INITIAL.
          MODIFY zztfi_0004 FROM TABLE @lt_ztfi004.
        ENDIF.

        cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection( log = l_log
                                                                     assign_to_current_appl_job = abap_true ).
      CATCH cx_bali_runtime INTO DATA(l_runtime_exception).
               IF 1 = 1.
          ENDIF.
    ENDTRY.


  ENDMETHOD.
ENDCLASS.
