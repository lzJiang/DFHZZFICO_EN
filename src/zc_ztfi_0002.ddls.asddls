@Metadata.allowExtensions: true
@EndUserText.label: '###GENERATED Core Data Service Entity'
@AccessControl.authorizationCheck: #CHECK
define root view entity ZC_ZTFI_0002
  provider contract TRANSACTIONAL_QUERY
  as projection on ZR_ZTFI_0002
{
  key Zcurrency,
  @Semantics.currencyCode: true
  Waers,
  Racct,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  LastChangedAt
  
}
