use serde::Serialize;
use std::fmt;

/// Serialize a value to a key-value string format, similar to serde_json::to_string_pretty
pub fn to_string<T: Serialize>(value: &T) -> Result<String, fmt::Error> {
    let mut serializer = KVSerializer::new();
    value.serialize(&mut serializer)?;
    Ok(serializer.output)
}

pub struct KVSerializer {
    pub output: String,
    current_key: Option<String>,
    first: bool,
}

impl KVSerializer {
    pub fn new() -> Self {
        Self {
            output: String::new(),
            current_key: None,
            first: true,
        }
    }

    fn add_value<T: fmt::Display>(&mut self, value: T) {
        if let Some(key) = self.current_key.take() {
            if !self.first {
                self.output.push('\n');
            }
            self.output.push_str(&format!("{}: {}", key, value));
            self.first = false;
        }
    }
}

impl Default for KVSerializer {
    fn default() -> Self {
        Self::new()
    }
}

impl<'a> serde::Serializer for &'a mut KVSerializer {
    type Ok = ();
    type Error = fmt::Error;

    type SerializeSeq = Self;
    type SerializeTuple = Self;
    type SerializeTupleStruct = Self;
    type SerializeTupleVariant = Self;
    type SerializeMap = Self;
    type SerializeStruct = Self;
    type SerializeStructVariant = Self;

    fn serialize_bool(self, v: bool) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_i8(self, v: i8) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_i16(self, v: i16) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_i32(self, v: i32) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_i64(self, v: i64) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_u8(self, v: u8) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_u16(self, v: u16) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_u32(self, v: u32) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_u64(self, v: u64) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_f32(self, v: f32) -> Result<(), Self::Error> {
        self.add_value(format!("{:.2}", v));
        Ok(())
    }

    fn serialize_f64(self, v: f64) -> Result<(), Self::Error> {
        self.add_value(format!("{:.2}", v));
        Ok(())
    }

    fn serialize_char(self, v: char) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_str(self, v: &str) -> Result<(), Self::Error> {
        self.add_value(v);
        Ok(())
    }

    fn serialize_bytes(self, _v: &[u8]) -> Result<(), Self::Error> {
        Err(fmt::Error)
    }

    fn serialize_none(self) -> Result<(), Self::Error> {
        self.add_value("null");
        Ok(())
    }

    fn serialize_some<T>(self, value: &T) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        value.serialize(self)
    }

    fn serialize_unit(self) -> Result<(), Self::Error> {
        Ok(())
    }

    fn serialize_unit_struct(self, _name: &'static str) -> Result<(), Self::Error> {
        Ok(())
    }

    fn serialize_unit_variant(
        self,
        _name: &'static str,
        _variant_index: u32,
        variant: &'static str,
    ) -> Result<(), Self::Error> {
        self.add_value(variant);
        Ok(())
    }

    fn serialize_newtype_struct<T>(
        self,
        _name: &'static str,
        value: &T,
    ) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        value.serialize(self)
    }

    fn serialize_newtype_variant<T>(
        self,
        _name: &'static str,
        _variant_index: u32,
        variant: &'static str,
        _value: &T,
    ) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize
    {
        self.add_value(variant);
        Ok(())
    }

    fn serialize_seq(self, _len: Option<usize>) -> Result<Self::SerializeSeq, Self::Error> {
        Ok(self)
    }

    fn serialize_tuple(self, _len: usize) -> Result<Self::SerializeTuple, Self::Error> {
        Ok(self)
    }

    fn serialize_tuple_struct(
        self,
        _name: &'static str,
        _len: usize,
    ) -> Result<Self::SerializeTupleStruct, Self::Error> {
        Ok(self)
    }

    fn serialize_tuple_variant(
        self,
        _name: &'static str,
        _variant_index: u32,
        _variant: &'static str,
        _len: usize,
    ) -> Result<Self::SerializeTupleVariant, Self::Error> {
        Ok(self)
    }

    fn serialize_map(self, _len: Option<usize>) -> Result<Self::SerializeMap, Self::Error> {
        Ok(self)
    }

    fn serialize_struct(
        self,
        _name: &'static str,
        _len: usize,
    ) -> Result<Self::SerializeStruct, Self::Error> {
        Ok(self)
    }

    fn serialize_struct_variant(
        self,
        _name: &'static str,
        _variant_index: u32,
        _variant: &'static str,
        _len: usize,
    ) -> Result<Self::SerializeStructVariant, Self::Error> {
        Ok(self)
    }
}

impl<'a> serde::ser::SerializeSeq for &'a mut KVSerializer {
    type Ok = ();
    type Error = fmt::Error;

    fn serialize_element<T>(&mut self, _value: &T) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        Ok(())
    }

    fn end(self) -> Result<(), Self::Error> {
        Ok(())
    }
}

impl<'a> serde::ser::SerializeTuple for &'a mut KVSerializer {
    type Ok = ();
    type Error = fmt::Error;

    fn serialize_element<T>(&mut self, _value: &T) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        Ok(())
    }

    fn end(self) -> Result<(), Self::Error> {
        Ok(())
    }
}

impl<'a> serde::ser::SerializeTupleStruct for &'a mut KVSerializer {
    type Ok = ();
    type Error = fmt::Error;

    fn serialize_field<T>(&mut self, _value: &T) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        Ok(())
    }

    fn end(self) -> Result<(), Self::Error> {
        Ok(())
    }
}

impl<'a> serde::ser::SerializeTupleVariant for &'a mut KVSerializer {
    type Ok = ();
    type Error = fmt::Error;

    fn serialize_field<T>(&mut self, _value: &T) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        Ok(())
    }

    fn end(self) -> Result<(), Self::Error> {
        Ok(())
    }
}

impl<'a> serde::ser::SerializeMap for &'a mut KVSerializer {
    type Ok = ();
    type Error = fmt::Error;

    fn serialize_key<T>(&mut self, _key: &T) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        Ok(())
    }

    fn serialize_value<T>(&mut self, _value: &T) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        Ok(())
    }

    fn end(self) -> Result<(), Self::Error> {
        Ok(())
    }
}

impl<'a> serde::ser::SerializeStruct for &'a mut KVSerializer {
    type Ok = ();
    type Error = fmt::Error;

    fn serialize_field<T>(&mut self, key: &'static str, value: &T) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        self.current_key = Some(key.to_string());
        value.serialize(&mut **self)?;
        Ok(())
    }

    fn end(self) -> Result<(), Self::Error> {
        Ok(())
    }
}

impl<'a> serde::ser::SerializeStructVariant for &'a mut KVSerializer {
    type Ok = ();
    type Error = fmt::Error;

    fn serialize_field<T>(&mut self, key: &'static str, value: &T) -> Result<(), Self::Error>
    where
        T: ?Sized + Serialize,
    {
        self.current_key = Some(key.to_string());
        value.serialize(&mut **self)?;
        Ok(())
    }

    fn end(self) -> Result<(), Self::Error> {
        Ok(())
    }
}
