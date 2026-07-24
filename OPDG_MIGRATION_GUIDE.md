# OPDG (On-Premises Data Gateway) Migration Guide

## Overview

While your current setup uses **direct connection** to on-prem SQL Server, you mentioned wanting to use **On-Premises Data Gateway (OPDG)** eventually. This guide explains when and how to migrate to OPDG.

---

## 🤔 When to Use OPDG

### Use Direct Connection (Current Setup) When:
- ✅ SQL Server has public IP or VPN access
- ✅ Firewall rules are manageable
- ✅ Small-scale testing/development
- ✅ You control network infrastructure

### Migrate to OPDG When:
- 🔒 Need enterprise-grade security
- 🏢 Corporate policies require gateway
- 🌐 SQL Server is behind corporate firewall (no public IP)
- 📈 Scaling to production workloads
- 🔐 Need centralized credential management
- 👥 Multiple users/services accessing on-prem data

---

## 🏗️ OPDG Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Microsoft Fabric                         │
│                  (Cloud Services)                           │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ HTTPS (Outbound only, port 443)
                  │ Encrypted connection
                  ▼
         ┌────────────────────┐
         │   Azure Relay      │
         │  (Secure Bridge)   │
         └─────────┬──────────┘
                   │
                   │ HTTPS (Outbound only)
                   ▼
┌─────────────────────────────────────────────────────────────┐
│            On-Premises Environment                          │
│                                                             │
│  ┌────────────────────────────────────────┐               │
│  │  On-Premises Data Gateway (OPDG)      │               │
│  │  - Installed on Windows Server/PC      │               │
│  │  - Manages connections                 │               │
│  │  - Encrypts data in transit            │               │
│  │  - No inbound firewall rules needed    │               │
│  └──────────────┬─────────────────────────┘               │
│                 │                                           │
│                 │ Local network connection                  │
│                 ▼                                           │
│  ┌────────────────────────────────────────┐               │
│  │    On-Prem SQL Server                  │               │
│  │    (HRSystem)                          │               │
│  └────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

### Key Security Features:
- **Outbound-only connections**: No inbound firewall rules needed
- **Encrypted communication**: All data encrypted in transit
- **Credential management**: Credentials stored securely
- **Audit logging**: Track all data access
- **No direct internet exposure**: SQL Server stays isolated

---

## 📋 OPDG Installation Steps

### Prerequisites:
- Windows Server 2016 or later, OR Windows 10/11 Pro
- .NET Framework 4.7.2 or later
- 8 GB RAM minimum (16 GB recommended)
- Local administrator rights
- Network access to on-prem SQL Server

### Step 1: Download OPDG

1. Go to: https://aka.ms/opdg
2. Download **On-premises data gateway (standard mode)**
3. Run installer: `GatewayInstall.exe`

### Step 2: Install OPDG

1. Launch installer
2. Select installation path (default: `C:\Program Files\On-premises data gateway`)
3. Accept terms
4. Click **Install**

### Step 3: Configure OPDG

1. After installation, the gateway configuration window opens
2. Sign in with your **Microsoft 365 / Azure AD account** (same as Fabric)
3. Click **Register a new gateway on this computer**
4. Enter gateway details:
   ```
   Gateway name: FabricWritebackGateway
   Recovery key: [Create strong password - SAVE THIS!]
   Region: [Match your Fabric region]
   ```
5. Click **Configure**

### Step 4: Test Gateway

1. In configuration window, go to **Service Settings** tab
2. Status should show: **Connected**
3. Click **Diagnostics** → **Test connections**
4. Select network: **On-premises**
5. Click **Test** - should succeed

---

## 🔧 Configure Fabric to Use OPDG

### Step 1: Verify Gateway in Fabric

1. Go to Fabric portal: https://app.fabric.microsoft.com
2. Click ⚙️ **Settings** → **Manage connections and gateways**
3. Select **Gateways** tab
4. You should see: `FabricWritebackGateway` (Status: Online)

### Step 2: Update On-Prem SQL Server Connection

#### Option A: Create New Connection with OPDG

1. In workspace **Fabric Writeback Demo**
2. Click **+ New** → **More options** → **Connection**
3. Select **SQL Server**
4. Configure:
   ```
   Connection name: OnPremSQLServer_OPDG
   Server: [internal server name, e.g., SQLSERVER01]
   Database: HRSystem
   Authentication: Windows or SQL Authentication
   
   ✅ Use data gateway: ON
   Gateway: Select "FabricWritebackGateway"
   ```
5. **Test Connection** → **Create**

#### Option B: Update Existing Connection

1. Go to **Manage connections and gateways**
2. Find connection: `OnPremSQLServer`
3. Click **...** → **Edit**
4. Enable **Use data gateway**
5. Select gateway: `FabricWritebackGateway`
6. **Save**

### Step 3: Update Pipelines

#### Update Pipeline 1 (IngestEmployees):
1. Open pipeline
2. Edit Copy activity
3. Source connection: Change to `OnPremSQLServer_OPDG` (or the updated connection)
4. **Validate** → **Save**

#### Update Pipeline 2 (SyncBackEmployees):
1. Open pipeline
2. Edit Copy activity destination
3. Connection: Change to `OnPremSQLServer_OPDG`
4. **Validate** → **Save**

### Step 4: Test End-to-End

1. Run Pipeline 1 (IngestEmployees)
2. Verify data copied to Fabric SQL DB
3. Update a record in Fabric SQL DB
4. Run Pipeline 2 (SyncBackEmployees)
5. Verify update synced to on-prem

---

## 🔐 Security Best Practices

### 1. Credential Management
- Use **Windows Authentication** when possible
- Store SQL credentials in Azure Key Vault
- Rotate credentials regularly (every 90 days)

### 2. Network Isolation
- Install OPDG on dedicated server (not domain controller)
- Use separate service account for gateway
- Restrict network access to SQL Server

### 3. Monitoring
- Enable diagnostic logging on gateway
- Set up alerts for gateway offline status
- Monitor gateway performance metrics

### 4. High Availability
- Install multiple gateways in cluster mode
- Configure automatic failover
- Test disaster recovery procedures

---

## 📊 OPDG vs Direct Connection Comparison

| Feature | Direct Connection | OPDG |
|---------|------------------|------|
| **Setup Complexity** | Low | Medium |
| **Security** | Medium | High |
| **Firewall Config** | Inbound rules required | Outbound only |
| **Enterprise Ready** | No | Yes |
| **Central Management** | No | Yes |
| **Cost** | Free | Free |
| **Performance** | Slightly faster | Very good |
| **Maintenance** | Low | Medium |
| **Best For** | Dev/Test | Production |

---

## 🚀 Migration Checklist

When migrating from direct connection to OPDG:

- [ ] Install OPDG on gateway server
- [ ] Configure gateway and verify online status
- [ ] Create/update connection in Fabric to use gateway
- [ ] Update Pipeline 1 to use new connection
- [ ] Test Pipeline 1 (ingest)
- [ ] Update Pipeline 2 to use new connection
- [ ] Test Pipeline 2 (sync back)
- [ ] Test end-to-end workflow
- [ ] Remove old direct connection (if desired)
- [ ] Update firewall rules (remove inbound rules if applicable)
- [ ] Document gateway server details
- [ ] Set up monitoring and alerts

---

## ⚡ Performance Tuning

### Gateway Performance Tips:

1. **Hardware**:
   - Dedicated server for gateway
   - SSD for gateway logs
   - 16 GB RAM for production

2. **Network**:
   - Low-latency connection to SQL Server
   - Gigabit Ethernet minimum
   - Consider gateway placement (same subnet as SQL Server)

3. **Configuration**:
   - Adjust concurrent operations:
     ```
     Settings → Service Settings → 
     Concurrent operations: 10 (default, increase to 20 for high volume)
     ```

4. **Monitoring**:
   - Enable performance monitoring
   - Review gateway logs regularly: `C:\Program Files\On-premises data gateway\Logs`

---

## 🛠️ Troubleshooting OPDG

### Issue: Gateway shows "Offline"

**Solutions:**
- Check gateway Windows service is running:
  ```powershell
  Get-Service -Name "PBIEgwService"
  ```
- Restart gateway service
- Check internet connectivity
- Verify firewall allows outbound HTTPS (port 443)

### Issue: Connection test fails

**Solutions:**
- Verify SQL Server name/IP is correct
- Check SQL Server allows gateway server
- Test SQL connection from gateway server:
  ```powershell
  Test-NetConnection -ComputerName SQLSERVER01 -Port 1433
  ```

### Issue: Pipeline fails with "Gateway not found"

**Solutions:**
- Verify gateway is online in Fabric portal
- Check connection is configured to use gateway
- Refresh gateway list in connection settings

---

## 📚 Additional Resources

- **OPDG Documentation**: https://learn.microsoft.com/data-integration/gateway/service-gateway-onprem
- **Gateway Architecture**: https://learn.microsoft.com/data-integration/gateway/service-gateway-onprem-indepth
- **Security Whitepaper**: https://aka.ms/opdg-security
- **Gateway FAQ**: https://learn.microsoft.com/power-bi/connect-data/service-gateway-onprem-faq

---

## 💡 Recommendations for Your Setup

### Current State (Direct Connection):
✅ Good for initial testing and proof of concept
✅ Faster to set up and test
✅ Suitable for development environment

### Future State (OPDG):
🎯 **Recommended timeline**: Migrate to OPDG within 1-2 weeks
🎯 **Reason**: Better security, enterprise-ready
🎯 **Effort**: 2-3 hours (install, configure, test)

### Migration Strategy:
1. **Week 1**: Build and test with direct connection (current approach)
2. **Week 2**: Install OPDG in parallel (don't remove direct connection yet)
3. **Week 3**: Test OPDG connections, update pipelines
4. **Week 4**: Fully migrate to OPDG, remove direct connection

This approach gives you time to validate the solution before introducing the gateway layer.

---

## ✅ Summary

- **Current setup (direct connection)**: Perfect for getting started quickly
- **OPDG**: Necessary for production deployments
- **Migration**: Straightforward, takes a few hours
- **Benefits**: Enhanced security, no inbound firewall rules, centralized management

You can proceed with your current direct connection approach now and migrate to OPDG when ready for production!
