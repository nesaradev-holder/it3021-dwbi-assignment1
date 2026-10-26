// Builds native SSIS 2022 packages through Microsoft's managed package SDK.
using System;
using System.IO;
using System.Collections.Generic;
using R = Microsoft.SqlServer.Dts.Runtime;
using RW = Microsoft.SqlServer.Dts.Runtime.Wrapper;
using PW = Microsoft.SqlServer.Dts.Pipeline.Wrapper;

public static class BankingSsisBuilder
{
    static R.Package NewPackage(string name, string dataDirectory)
    {
        R.Package package = new R.Package();
        package.Name = name;
        package.Description = "Synthetic banking warehouse demonstration; SQL Server 2022 SSIS runtime.";
        package.CreatorName = "Banking Demo";
        package.CreatorComputerName = "localhost";
        package.ProtectionLevel = R.DTSProtectionLevel.DontSaveSensitive;
        package.MaxConcurrentExecutables = 1;
        package.Variables.Add("DataDirectory", false, "User", dataDirectory);
        return package;
    }

    static R.ConnectionManager Database(R.Package package, string name, string server, string database)
    {
        R.ConnectionManager manager = package.Connections.Add("OLEDB");
        manager.Name = name;
        manager.ConnectionString = "Provider=MSOLEDBSQL;Data Source=" + server +
            ";Initial Catalog=" + database +
            ";Integrated Security=SSPI;Use Encryption for Data=True;Trust Server Certificate=True;";
        return manager;
    }

    static R.TaskHost SqlTask(R.Package package, R.ConnectionManager manager, string name, string statement)
    {
        R.TaskHost host = (R.TaskHost)package.Executables.Add("STOCK:SQLTask");
        host.Name = name;
        object task = host.InnerObject;
        // The task derives its connection type from the selected connection manager.
        task.GetType().GetProperty("Connection").SetValue(task, manager.ID, null);
        task.GetType().GetProperty("SqlStatementSource").SetValue(task, statement, null);
        task.GetType().GetProperty("BypassPrepare").SetValue(task, true, null);
        return host;
    }

    static void After(R.Package package, R.Executable previous, R.Executable next)
    {
        R.PrecedenceConstraint constraint = package.PrecedenceConstraints.Add(previous, next);
        constraint.Value = R.DTSExecResult.Success;
    }

    static void Bind(PW.IDTSComponentMetaData100 component, R.ConnectionManager manager)
    {
        component.RuntimeConnectionCollection[0].ConnectionManager = R.DtsConvert.GetExtendedInterface(manager);
        component.RuntimeConnectionCollection[0].ConnectionManagerID = manager.ID;
    }

    static void Refresh(PW.CManagedComponentWrapper component)
    {
        component.AcquireConnections(null);
        try { component.ReinitializeMetaData(); }
        finally { component.ReleaseConnections(); }
    }

    static R.TaskHost DataFlow(R.Package package, R.ConnectionManager source,
        R.ConnectionManager warehouse, string name, string query, string destination, bool flatFile)
    {
        R.TaskHost host = (R.TaskHost)package.Executables.Add("STOCK:PipelineTask");
        host.Name = name;
        PW.MainPipe pipe = (PW.MainPipe)host.InnerObject;
        PW.IDTSComponentMetaData100 input = pipe.ComponentMetaDataCollection.New();
        input.Name = flatFile ? "CSV source" : "SQL source";
        input.ComponentClassID = flatFile ? "DTSAdapter.FlatFileSource.8" : "DTSAdapter.OLEDBSource.8";
        PW.CManagedComponentWrapper inputDesign = input.Instantiate();
        inputDesign.ProvideComponentProperties();
        Bind(input, source);
        if (!flatFile)
        {
            inputDesign.SetComponentProperty("AccessMode", 2);
            inputDesign.SetComponentProperty("SqlCommand", query);
        }
        Refresh(inputDesign);

        PW.IDTSComponentMetaData100 output = pipe.ComponentMetaDataCollection.New();
        output.Name = "Warehouse staging destination";
        output.ComponentClassID = "DTSAdapter.OLEDBDestination.8";
        PW.CManagedComponentWrapper outputDesign = output.Instantiate();
        outputDesign.ProvideComponentProperties();
        Bind(output, warehouse);
        outputDesign.SetComponentProperty("AccessMode", 3);
        outputDesign.SetComponentProperty("OpenRowset", destination);
        outputDesign.SetComponentProperty("FastLoadKeepNulls", true);
        PW.IDTSPath100 path = pipe.PathCollection.New();
        path.AttachPathAndPropagateNotifications(input.OutputCollection[0], output.InputCollection[0]);
        Refresh(outputDesign);

        PW.IDTSInput100 target = output.InputCollection[0];
        PW.IDTSVirtualInput100 available = target.GetVirtualInput();
        foreach (PW.IDTSVirtualInputColumn100 column in available.VirtualInputColumnCollection)
        {
            PW.IDTSInputColumn100 selected = outputDesign.SetUsageType(
                target.ID, available, column.LineageID, PW.DTSUsageType.UT_READONLY);
            int externalId = 0;
            foreach (PW.IDTSExternalMetadataColumn100 external in target.ExternalMetadataColumnCollection)
                if (String.Equals(external.Name, column.Name, StringComparison.OrdinalIgnoreCase))
                    externalId = external.ID;
            if (externalId == 0) throw new InvalidOperationException("No destination column for " + column.Name);
            outputDesign.MapInputColumn(target.ID, selected.ID, externalId);
        }
        return host;
    }

    static R.ConnectionManager FlatFile(R.Package package, string dataDirectory, string name,
        string filename, string[] names, int[] widths)
    {
        R.ConnectionManager manager = package.Connections.Add("FLATFILE");
        manager.Name = name;
        manager.ConnectionString = Path.Combine(dataDirectory, filename);
        RW.IDTSConnectionManagerFlatFile100 file = (RW.IDTSConnectionManagerFlatFile100)manager.InnerObject;
        file.Format = "Delimited";
        file.Unicode = true;
        file.ColumnNamesInFirstDataRow = true;
        file.HeaderRowDelimiter = "\r\n";
        file.TextQualifier = "\"";
        for (int index = 0; index < names.Length; index++)
        {
            RW.IDTSConnectionManagerFlatFileColumn100 column = file.Columns.Add();
            column.ColumnType = "Delimited";
            column.ColumnDelimiter = index == names.Length - 1 ? "\r\n" : ",";
            column.DataType = RW.DataType.DT_WSTR;
            column.MaximumWidth = widths[index];
            column.TextQualified = true;
            ((RW.IDTSName100)column).Name = names[index];
        }
        manager.SetExpression("ConnectionString", "@[User::DataDirectory] + \"\\\\" + filename + "\"");
        return manager;
    }

    static void Save(R.Package package, string root, string filename, Dictionary<string,string> flatFiles)
    {
        package.Variables["User::DataDirectory"].Value = "data\\generated";
        foreach (KeyValuePair<string,string> entry in flatFiles)
            package.Connections[entry.Key].ConnectionString = Path.Combine("data", "generated", entry.Value);
        string path = Path.Combine(root, "ssis", filename);
        new R.Application().SaveToXml(path, package, null);
        string xml = File.ReadAllText(path);
        if (xml.IndexOf(root, StringComparison.OrdinalIgnoreCase) >= 0 ||
            xml.IndexOf("C:\\Users\\", StringComparison.OrdinalIgnoreCase) >= 0)
            throw new InvalidOperationException("Package contains a local device path; do not publish it.");
    }

    static void BuildCore(string root, string server)
    {
        string data = Path.Combine(root, "data", "generated");
        R.Package package = NewPackage("BankingWarehouse", data);
        try
        {
            R.ConnectionManager source = Database(package, "Operational source", server, "BankingOLTP");
            R.ConnectionManager warehouse = Database(package, "Warehouse", server, "BankingDW");
            R.Executable previous = SqlTask(package, warehouse, "Prepare source staging", "EXEC etl.PrepareCore;");
            string[] tables = { "Branch", "Customer", "Account", "Deposit" };
            string[] queries = {
                "SELECT branch_id,branch_name,city FROM dbo.Branch",
                "SELECT customer_id,customer_name,city FROM dbo.Customer",
                "SELECT account_id,branch_id,customer_id FROM dbo.Account",
                "SELECT transaction_id,account_id,transaction_branch_id,transaction_date,amount FROM dbo.Deposit"
            };
            for (int index = 0; index < tables.Length; index++)
            {
                R.TaskHost flow = DataFlow(package, source, warehouse, "Extract " + tables[index],
                    queries[index], "[stg].[" + tables[index] + "]", false);
                After(package, previous, flow);
                previous = flow;
            }
            R.ConnectionManager history = FlatFile(package, data, "Customer history file", "customer_changes.csv",
                new string[] { "customer_id", "city", "effective_from" }, new int[] {100,200,50});
            R.TaskHost historyFlow = DataFlow(package, history, warehouse, "Extract customer history CSV", null,
                "[stg].[CustomerChange]", true);
            After(package, previous, historyFlow);
            R.TaskHost transform = SqlTask(package, warehouse, "Load dimensions then facts", "EXEC etl.LoadWarehouse;");
            After(package, historyFlow, transform);
            Save(package, root, "BankingWarehouse.dtsx", new Dictionary<string,string> {
                {history.Name, "customer_changes.csv"}
            });
        }
        catch
        {
            foreach (R.DtsError error in package.Errors) Console.Error.WriteLine(error.Description);
            throw;
        }
    }

    static void BuildCompletion(string root, string server)
    {
        string data = Path.Combine(root, "data", "generated");
        string completionPath = Path.Combine(data, "completion_updates.csv");
        if (!File.Exists(completionPath))
            File.WriteAllText(completionPath, "transaction_id,complete_time\r\n", System.Text.Encoding.Unicode);
        R.Package package = NewPackage("CompletionUpdates", data);
        try
        {
            R.ConnectionManager warehouse = Database(package, "Warehouse", server, "BankingDW");
            R.ConnectionManager completion = FlatFile(package, data, "Completion update file", "completion_updates.csv",
                new string[] { "transaction_id", "complete_time" }, new int[] {100,50});
            R.TaskHost prepare = SqlTask(package, warehouse, "Prepare completion staging", "EXEC etl.PrepareCompletion;");
            R.TaskHost flow = DataFlow(package, completion, warehouse, "Extract completion CSV", null,
                "[stg].[Completion]", true);
            R.TaskHost update = SqlTask(package, warehouse, "Apply completions and record rejects", "EXEC etl.ApplyCompletions;");
            After(package, prepare, flow);
            After(package, flow, update);
            Save(package, root, "CompletionUpdates.dtsx", new Dictionary<string,string> {
                {completion.Name, "completion_updates.csv"}
            });
        }
        catch
        {
            foreach (R.DtsError error in package.Errors) Console.Error.WriteLine(error.Description);
            throw;
        }
    }

    public static void Build(string root, string server)
    {
        if (server.Contains(";")) throw new ArgumentException("Supply a server name, not a connection string.");
        BuildCore(root, server);
        BuildCompletion(root, server);
    }
}
