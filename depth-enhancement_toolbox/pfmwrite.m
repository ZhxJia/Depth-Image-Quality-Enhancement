function pfmwrite(D,filename,endianess)
%UNTITLED2 此处显示有关此函数的摘要
%   此处显示详细说明
[rows, cols] = size(D);
scale = max(max(D));
if scale > 0
    scale = -1 / scale;
else
    scale = -1;
end

fid = fopen(filename, 'wb');
%write pfm header
fprintf(fid, 'Pf\n');
fprintf(fid, '%d %d\n', cols, rows);
fprintf(fid, '%f\n', scale);

fwrite(fid, D(end:-1:1, :)', 'single');
fclose(fid);
end

