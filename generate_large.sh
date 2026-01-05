echo "fungsi test_large()" > examples/large_test.fox
for i in {1..300}; do
    echo "    var x$i = $i" >> examples/large_test.fox
    echo "    cetak(x$i)" >> examples/large_test.fox
done
echo "tutup_fungsi" >> examples/large_test.fox
echo "panggil test_large()" >> examples/large_test.fox
