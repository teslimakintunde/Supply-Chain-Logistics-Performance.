# Supply Chain & Logistics Performance

**MySQL + Power BI | Supplier Reliability, Warehouse Execution & Fulfillment Analytics**

This project analyses **supplier reliability, inbound supply performance, warehouse execution, regional fulfillment, delivery performance, and logistics costs** across a multi-year supply chain dataset using MySQL and Power BI.

The objective was to move beyond basic logistics reporting and identify **where supply-chain performance breaks down**, **how upstream supplier and warehouse conditions relate to downstream service outcomes**, and **where fulfillment costs can be better managed**.

---

## Dashboard Overview

### Page 1 — Delivery & Service Performance

**Business Question**  
> Are customers receiving orders reliably, and where is delivery performance breaking down?

**Key Insight**  
Of **70,309** orders, **55,092** reached delivered status (**78.36%** delivered rate). Among the **63,305** orders with an actual delivery date, **87.03%** were delivered on time, while **12.97%** were delayed.

Regional performance is highly uneven:
- **West** ≈ **95.05%** on-time delivery  
- **East** ≈ **60.98%** on-time delivery  
- Average delivery time: **6.88 days** (East) vs **4.14 days** overall  

**Business Implication**  
Delivery performance should be managed as a **regional service problem** rather than a single network-wide KPI. The East region requires deeper investigation across inventory availability, inbound supply, warehouse processing, carrier performance, route conditions, and backlog.

---

### Page 2 — Supplier Reliability & Inbound Risk

**Business Question**  
> Are suppliers providing inventory reliably, on time, and at the required quality level?

**Key Insight**  
Supplier performance improved between 2024 and 2025:
- Fill rate: **86.68% → 88.09%**  
- Average lead time: **18.39 → 17.44 days**  
- Defect rate: **4.77% → 4.48%**  

However, network averages conceal significant supplier-level variation. Some suppliers show very high defect rates and substantial lead-time deviations.

Across the network, actual lead time totals **81,807 days** versus **72,844 planned days** — an aggregate **8,963-day variance**.

**Business Implication**  
Move beyond average performance toward **risk-based supplier segmentation**, combining fill rate, lead-time variance, defect rate, reliability, and purchasing exposure.

---

### Page 3 — Warehouse & Regional Fulfillment

**Business Question**  
> Where does inbound supply become an internal fulfillment bottleneck, and how does operational performance vary across the network?

**Key Insight**  
Warehouse performance varies materially:
- **Enugu**: lowest fill rate (**79.95%**) and longest average lead time (**22.83 days**)  
- Network average: fill rate **87.48%**, lead time **17.85 days**  

Regional fulfillment also varies:
- **East**: **6.88** average delivery days  
- **West**: **3.26** average delivery days  

The model does not directly map individual sales orders to warehouses, so any link between Enugu’s performance and East-region delivery should be treated as a **root-cause hypothesis requiring validation**.

**Business Implication**  
Investigate warehouse-level differences in inventory availability, inbound processing, order backlog, picking/packing execution, allocation, and regional transportation capacity before redesigning the network.

---

### Page 4 — Fulfillment Cost & Supply Chain Economics

**Business Question**  
> What does the supply chain cost, where is fulfillment spend concentrated, and where are cost-to-serve opportunities emerging?

**Key Insight**  
Total fulfillment expenditure ≈ **$7.11M**:
- Freight: **$4.50M**  
- Shipping: **$2.61M**  

Shipping costs rise sharply toward year-end:
- November ≈ **$301.9K**  
- December ≈ **$349.1K**  

Logistics cost varies by order value, region, supplier freight spend, and time period.

**Business Implication**  
Manage fulfillment economics through **cost-to-serve analysis**, focusing on freight negotiation, shipment consolidation, carrier/lane performance, supplier shipping terms, regional network design, and peak-season capacity planning.

---

## Key Business Findings

- **Delivery performance is uneven**: 87.03% on-time among orders with actual delivery, but East ≈ 60.98% vs West ≈ 95.05%  
- **Successful fulfillment is a separate challenge**: only 78.36% of all orders reached delivered status  
- **Supplier performance improved** in 2025 (higher fill rates, lower lead times, lower defect rates)  
- **Supplier averages conceal concentrated risk**: individual suppliers show materially higher defect rates and lead-time deviations  
- **Warehouse performance is localized**: Enugu has the weakest fill rate (79.95%) and longest lead time (22.83 days)  
- **Regional service gaps are significant**: East averages 6.88 delivery days  
- **Fulfillment cost is freight-heavy**: $4.50M of the $7.11M total comes from freight  
- **Peak-season logistics costs require planning**: November + December ≈ $650.9K of annual shipping spend  
- **Upstream and downstream metrics should be analysed together** for stronger diagnostics  

---

## Strategic Recommendations

1. Establish **risk-based supplier performance management** using fill rate, defect rate, lead-time variance, reliability, and spend  
2. Prioritise **CAPA and supplier development** for suppliers with persistent quality and delivery deviations  
3. Conduct a dedicated **East-region root-cause investigation** (inventory, supplier allocation, warehouse, carrier, transit time, backlog)  
4. Investigate **Enugu warehouse performance** through inventory, inbound processing, backlog, and fulfillment-cycle analysis  
5. Manage freight as a **strategic procurement category** (rates, lane economics, consolidation, shipping terms)  
6. Introduce **cost-to-serve KPIs** (cost per order, cost per unit, freight per successful delivery, logistics % of revenue)  
7. Prepare for peak periods via inventory pre-positioning, supplier commitments, carrier capacity, and regional safety stock  
8. Connect supplier, warehouse, delivery, and cost metrics into a **single supply-chain performance framework**  

---

## Data & Analytics Approach

### MySQL
- Data cleaning and transformation  
- Supply-chain fact and dimension modelling  
- Supplier, warehouse, product, and regional analysis  
- Lead-time and fulfillment calculations  
- Delivery and order-level performance analysis  
- Supplier reliability and quality analysis  
- Logistics cost aggregation  
- Business-rule-based segmentation and classification  

### Power BI
- Executive supply-chain dashboard  
- KPI development and operational scorecards  
- Supplier, warehouse, and regional performance analysis  
- Delivery-service analysis  
- Fulfillment cost and logistics economics  
- Interactive filtering across suppliers, warehouses, products, regions, and time  
- Executive-level operational reporting  

---

## Business Impact

The analysis moves supply-chain reporting from:

> “How much did we ship, how long did delivery take, and how much did logistics cost?”

to:

> “Where is supply-chain performance breaking down, what upstream conditions may be contributing, and where should management investigate cost and service improvements?”

The resulting framework connects:

**Supplier reliability → Inbound availability & quality → Warehouse execution → Regional fulfillment → Delivery performance → Fulfillment cost → Customer & margin impact**

This provides a data-driven foundation for **supplier management, warehouse optimisation, regional fulfillment improvement, transportation planning, and cost-to-serve management**.

---

## Tech Stack

| Tool         | Role                                              |
|--------------|---------------------------------------------------|
| **MySQL**    | Data cleaning, transformation, modelling & analysis |
| **Power BI** | Executive dashboards, visualisation & scorecards  |
