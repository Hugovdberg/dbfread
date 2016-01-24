function info = info(fid)
%DBFINFO Read header information from DBF file.
    dc = dbf.mixin.DBFConsts;

    % Open file if string is passed
    standalone = ischar(fid);
    if standalone
        fid = fopen(fid, dc.READ_BINARY);
    end
    info.Filename = fopen(fid);

    fseek(fid, dc.DBF_VERSION_OFFSET, dc.BEGIN_OF_FILE);
    data = fread(fid, ...
                 dc.DBF_VERSION_NUMVALS+dc.DATE_MODIFIED_NUMVALS, ...
                 dc.INT8, ...
                 dc.READ_CONTIGUOUS, ...
                 dc.LITTLE_ENDIAN);
    info.DBFVersion = data(1);
    info.FileModDate = datenummx([data(2)+1900, data(3), data(4)]);

    info.NumRecords = fread(fid, ...
                            dc.NUM_RECORDS_NUMVALS, ...
                            dc.INT32, ...
                            dc.READ_CONTIGUOUS, ...
                            dc.LITTLE_ENDIAN);

    lengths = fread(fid, ...
                    dc.HEADER_LENGTH_NUMVALS+dc.RECORD_LENGTH_NUMVALS, ...
                    dc.INT16, ...
                    dc.READ_CONTIGUOUS, ...
                    dc.LITTLE_ENDIAN);
    info.HeaderLength = lengths(1);
    info.RecordLength = lengths(2);

    numFields = (info.HeaderLength-...
                 dc.FILE_HEADER_LENGTH-...
                 dc.HEADER_TERMINATOR_LENGTH) /...
                dc.FIELD_RECORD_LENGTH;
    info.NumFields = numFields;

    % Read the field names.
    fseek(fid, dc.FILE_HEADER_LENGTH, dc.BEGIN_OF_FILE);
    data = fread(fid, ...
                 [dc.FIELD_NAME_NUMVALS, numFields], ...
                 dc.FIELD_NAME_DATATYPE, ...
                 dc.FIELD_RECORD_LENGTH-dc.FIELD_NAME_NUMVALS, ...
                 dc.LITTLE_ENDIAN);
    data(data == 0) = ' '; % Replace nulls with blanks
    names = cellstr(data')';

    % Read field types.
    fseek(fid, dc.FILE_HEADER_LENGTH+dc.FIELD_TYPE_OFFSET, dc.BEGIN_OF_FILE);
    dbftypes = fread(fid, ...
                     [numFields, dc.FIELD_TYPE_NUMVALS], ...
                     dc.FIELD_TYPE_DATATYPE, ...
                     dc.FIELD_RECORD_LENGTH-dc.FIELD_TYPE_NUMVALS, ...
                     dc.LITTLE_ENDIAN);

    % Convert DBF field types to MATLAB types.
    typeConv = dbf.mixin.getConverter(upper(dbftypes));

    % Read field lengths and precision. Calculate field offset within
    % record from lengths.
    fseek(fid, dc.FILE_HEADER_LENGTH+dc.FIELD_LENGTH_OFFSET, dc.BEGIN_OF_FILE);
    lengths = fread(fid, ...
                    [dc.FIELD_LENGTH_NUMVALS, numFields], ...
                    dc.FIELD_LENGTH_DATATYPE, ...
                    dc.FIELD_RECORD_LENGTH-dc.FIELD_LENGTH_NUMVALS, ...
                    dc.LITTLE_ENDIAN);
    offsets = cumsum([0 lengths(1:end-1)]);

    fseek(fid, dc.FILE_HEADER_LENGTH+dc.FIELD_PRECISION_OFFSET, dc.BEGIN_OF_FILE);
    decimals = fread(fid, ...
                     [dc.FIELD_PRECISION_NUMVALS, numFields], ...
                     dc.FIELD_PRECISION_DATATYPE, ...
                     dc.FIELD_RECORD_LENGTH-dc.FIELD_PRECISION_NUMVALS, ...
                     dc.LITTLE_ENDIAN);

    fseek(fid, dc.FILE_HEADER_LENGTH+dc.FIELD_FLAGS_OFFSET, dc.BEGIN_OF_FILE);
    flags = fread(fid, ...
                  [dc.FIELD_FLAGS_NUMVALS, numFields], ...
                  dc.FIELD_FLAGS_DATATYPE, ...
                  dc.FIELD_RECORD_LENGTH-dc.FIELD_FLAGS_NUMVALS, ...
                  dc.LITTLE_ENDIAN);

    % Return a struct array.
    dealc = dbf.mixin.dealc;
    [fieldInfo(1:numFields).Name] = names{:};
    [fieldInfo.RawType] = dealc(cellstr(dbftypes));
    [fieldInfo.Type] = typeConv.MATLABType;
    [fieldInfo.ConvFunc] = typeConv.ConvFunc;
    [fieldInfo.Offset] = dealc(num2cell(offsets));
    [fieldInfo.Length] = dealc(num2cell(lengths));
    [fieldInfo.Decimals] = dealc(num2cell(decimals));
    [fieldInfo.Flags] = dealc(num2cell(flags));

    info.FieldInfo = fieldInfo;

    if standalone
        fclose(fid);
    end
end
